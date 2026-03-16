import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// Health Connect Service - Unified health data integration
/// 
/// This service uses the `health` package to integrate with:
/// - Health Connect on Android (replaces Fitbit and Samsung Health)
/// - Apple Health on iOS
class HealthConnectService {
  // Singleton instance
  static final HealthConnectService _instance = HealthConnectService._internal();
  factory HealthConnectService() => _instance;
  HealthConnectService._internal();

  final Health _health = Health();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Connection state
  bool _isAuthorized = false;
  
  // Cache to prevent excessive API calls
  HealthData? _cachedData;
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 2);
  
  // Progress callback for sync operations
  void Function(String message, double percent, int step, int total)? progressCallback;

  // Stream controller for health data updates
  final StreamController<HealthData> _dataStreamController = 
      StreamController<HealthData>.broadcast();
  
  /// Stream of health data updates
  Stream<HealthData> get dataStream => _dataStreamController.stream;
  
  /// Whether the service is authorized to access health data
  bool get isAuthorized => _isAuthorized;

  /// Register a progress callback for sync operations
  void registerProgressCallback(
    void Function(String message, double percent, int step, int total) callback,
  ) {
    progressCallback = callback;
  }

  /// Health data types to request
  static List<HealthDataType> get _healthDataTypes {
    if (Platform.isAndroid) {
      // Health Connect supported data types on Android (minimum scope)
      return [
        HealthDataType.STEPS,
        HealthDataType.TOTAL_CALORIES_BURNED,
      ];
    } else {
      // Apple Health data types on iOS
      return [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
      ];
    }
  }

  /// Request authorization to access health data
  Future<bool> requestAuthorization() async {
    _notifyProgress('Checking health permissions...', 0.1, 1, 4);
    
    try {
      // Configure the health plugin
      await _health.configure();
      
      _notifyProgress('Checking existing permissions...', 0.3, 2, 4);
      
      // First check if we already have permissions
      final permissions = _healthDataTypes.map((_) => HealthDataAccess.READ).toList();
      final hasPermissions = await _health.hasPermissions(
        _healthDataTypes,
        permissions: permissions,
      );
      
      if (hasPermissions == true) {
        // Already authorized
        _isAuthorized = true;
        _notifyProgress('Already authorized!', 1.0, 4, 4);
        if (kDebugMode) {
          debugPrint('[HealthConnect] Already has permissions');
        }
        return true;
      }
      
      _notifyProgress('Requesting authorization...', 0.6, 3, 4);
      
      // Request authorization for health data types
      final authorized = await _health.requestAuthorization(
        _healthDataTypes,
        permissions: permissions,
      );
      
      _isAuthorized = authorized;
      
      _notifyProgress(
        authorized ? 'Authorization granted!' : 'Authorization denied',
        1.0,
        4,
        4,
      );
      
      if (kDebugMode) {
        debugPrint('[HealthConnect] Authorization result: $authorized');
      }
      
      return authorized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HealthConnect] Authorization error: $e');
      }
      // If there's an error but permissions might already be granted, try to fetch data
      _isAuthorized = false;
      return false;
    }
  }

  /// Check if we have health permissions without requesting
  Future<bool> checkPermissions() async {
    try {
      await _health.configure();
      final permissions = _healthDataTypes.map((_) => HealthDataAccess.READ).toList();
      final hasPermissions = await _health.hasPermissions(
        _healthDataTypes,
        permissions: permissions,
      );
      _isAuthorized = hasPermissions == true;
      return _isAuthorized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HealthConnect] Check permissions error: $e');
      }
      return false;
    }
  }

  /// Check if Health Connect is available on this device
  Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) {
      return false; // Health Connect is Android-only
    }
    
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HealthConnect] SDK status check error: $e');
      }
      return false;
    }
  }

  /// Install Health Connect app if not available
  Future<void> installHealthConnect() async {
    if (Platform.isAndroid) {
      try {
        await _health.installHealthConnect();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[HealthConnect] Install error: $e');
        }
      }
    }
  }

  /// Open Health Connect app permission screen
  Future<void> openHealthConnectPermissions() async {
    if (Platform.isAndroid) {
      try {
        // Try to open Health Connect app directly
        const healthConnectUrl = 'healthconnect://permissions';
        final uri = Uri.parse(healthConnectUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          // Fallback: open general Health Connect app
          const fallbackUrl = 'healthconnect://';
          final fallbackUri = Uri.parse(fallbackUrl);
          if (await canLaunchUrl(fallbackUri)) {
            await launchUrl(fallbackUri);
          } else {
            // Last resort: open Play Store page
            const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
            final playUri = Uri.parse(playStoreUrl);
            if (await canLaunchUrl(playUri)) {
              await launchUrl(playUri);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[HealthConnect] Open permissions error: $e');
        }
      }
    }
  }

  /// Fetch health data for a given time range
  Future<HealthData> fetchHealthData({
    DateTime? startTime,
    DateTime? endTime,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final start = startTime ?? DateTime(now.year, now.month, now.day);
    final end = endTime ?? now;

    // Return cached data if still valid and not forcing refresh
    if (!forceRefresh && _cachedData != null && _lastFetchTime != null) {
      final cacheAge = now.difference(_lastFetchTime!);
      if (cacheAge < _cacheExpiry) {
        if (kDebugMode) {
          debugPrint('[HealthConnect] Returning cached data (${cacheAge.inSeconds}s old)');
        }
        return _cachedData!;
      }
    }

    _notifyProgress('Fetching health data...', 0.2, 1, 5);

    if (!_isAuthorized) {
      final authorized = await requestAuthorization();
      if (!authorized) {
        throw HealthConnectException('Not authorized to access health data');
      }
    }

    _notifyProgress('Reading steps...', 0.4, 2, 5);
    
    int? steps;
    double? calories;
    double? distance;

    try {
      // Get all health data points
      final healthData = await _health.getHealthDataFromTypes(
        types: _healthDataTypes,
        startTime: start,
        endTime: end,
      );

      _notifyProgress('Processing data...', 0.6, 3, 5);

      // Process the data points
      for (final dataPoint in healthData) {
        final value = dataPoint.value;
        
        switch (dataPoint.type) {
          case HealthDataType.STEPS:
            if (value is NumericHealthValue) {
              steps = (steps ?? 0) + value.numericValue.toInt();
            }
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
          case HealthDataType.TOTAL_CALORIES_BURNED:
            if (value is NumericHealthValue) {
              calories = (calories ?? 0) + value.numericValue.toDouble();
            }
            break;
          case HealthDataType.DISTANCE_WALKING_RUNNING:
          case HealthDataType.DISTANCE_DELTA:
            if (value is NumericHealthValue) {
              distance = (distance ?? 0) + value.numericValue.toDouble();
            }
            break;
          default:
            break;
        }
      }

      _notifyProgress('Data sync complete!', 1.0, 5, 5);

      final healthResult = HealthData(
        timestamp: DateTime.now(),
        steps: steps,
        calories: calories?.toInt(),
        distance: distance,
        source: Platform.isAndroid ? 'Health Connect' : 'Apple Health',
      );

      // Cache the result
      _cachedData = healthResult;
      _lastFetchTime = DateTime.now();

      // Broadcast the data
      _dataStreamController.add(healthResult);

      return healthResult;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HealthConnect] Fetch error: $e');
      }
      rethrow;
    }
  }

  /// Sync health data and save to Firestore
  Future<HealthData?> syncHealthData(String userId) async {
    try {
      _notifyProgress('Starting health sync...', 0.1, 1, 6);
      
      final healthData = await fetchHealthData();
      
      _notifyProgress('Saving to cloud...', 0.9, 5, 6);
      
      // Save to Firestore
      await _saveToFirestore(userId, healthData);
      
      _notifyProgress('Sync complete!', 1.0, 6, 6);
      
      return healthData;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HealthConnect] Sync error: $e');
      }
      return null;
    }
  }

  /// Save health data to Firestore
  Future<void> _saveToFirestore(String userId, HealthData data) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('healthData')
        .doc(DateTime.now().toIso8601String().split('T')[0]);
    
    await docRef.set({
      'steps': data.steps,
      'calories': data.calories,
      'distance': data.distance,
      'source': data.source,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get the current user's UID
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Clean up resources
  void dispose() {
    _dataStreamController.close();
  }

  void _notifyProgress(String message, double percent, int step, int total) {
    progressCallback?.call(message, percent, step, total);
  }
}

/// Health data model
class HealthData {
  final DateTime timestamp;
  final int? steps;
  final int? calories;
  final double? distance;
  final String source;

  HealthData({
    required this.timestamp,
    this.steps,
    this.calories,
    this.distance,
    required this.source,
  });

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'steps': steps,
      'calories': calories,
      'distance': distance,
      'source': source,
    };
  }

  /// Check if any health data is available
  bool get hasData {
    return steps != null ||
        calories != null ||
        distance != null;
  }

  /// Get distance in kilometers
  double? get distanceKm {
    if (distance == null) return null;
    return distance! / 1000.0;
  }
}

/// Exception for Health Connect errors
class HealthConnectException implements Exception {
  final String message;
  final dynamic originalError;

  HealthConnectException(this.message, [this.originalError]);

  @override
  String toString() {
    if (originalError != null) {
      return 'HealthConnectException: $message (Original: $originalError)';
    }
    return 'HealthConnectException: $message';
  }
}
