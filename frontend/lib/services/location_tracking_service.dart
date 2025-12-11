import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trek.dart';

/// Location tracking service for recording treks
class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final List<GeoPoint> _recordedPoints = [];
  DateTime? _startTime;
  bool _isRecording = false;
  bool _isPaused = false;
  
  // Callbacks
  void Function(GeoPoint point)? onPointRecorded;
  void Function(double distance)? onDistanceUpdated;
  void Function(Position position)? onPositionUpdated;
  
  // Stats
  double _totalDistance = 0;
  double _elevationGain = 0;
  double _elevationLoss = 0;
  double _maxSpeed = 0;
  double _currentSpeed = 0;
  double _currentElevation = 0;
  
  // Getters
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  DateTime? get startTime => _startTime;
  List<GeoPoint> get recordedPoints => List.unmodifiable(_recordedPoints);
  double get totalDistance => _totalDistance;
  double get elevationGain => _elevationGain;
  double get elevationLoss => _elevationLoss;
  double get maxSpeed => _maxSpeed;
  double get currentSpeed => _currentSpeed;
  double get currentElevation => _currentElevation;
  
  Duration get elapsedTime {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Initialize location permission at app startup (non-blocking, doesn't throw)
  static Future<void> initializePermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        debugPrint('[Location] Requesting location permission...');
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        debugPrint('[Location] User granted location permission');
      } else if (permission == LocationPermission.denied) {
        debugPrint('[Location] User denied location permission');
      } else if (permission == LocationPermission.deniedForever) {
        debugPrint('[Location] Location permission permanently denied');
      }
    } catch (e) {
      debugPrint('[Location] Error requesting permission: $e');
    }
  }

  /// Check and request location permission
  Future<LocationPermission> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Location services are disabled');
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionException('Location permission denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionException(
        'Location permissions are permanently denied. Please enable in settings.'
      );
    }
    
    return permission;
  }
  
  /// Get current location
  Future<Position> getCurrentLocation() async {
    await checkAndRequestPermission();
    
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
  
  /// Start recording a trek
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    await checkAndRequestPermission();
    
    _recordedPoints.clear();
    _totalDistance = 0;
    _elevationGain = 0;
    _elevationLoss = 0;
    _maxSpeed = 0;
    _startTime = DateTime.now();
    _isRecording = true;
    _isPaused = false;
    
    // Get initial position
    final initialPosition = await getCurrentLocation();
    _addPoint(initialPosition);
    
    // Start listening for location updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Location error: $error');
        }
      },
    );
  }
  
  void _onPositionUpdate(Position position) {
    if (!_isRecording || _isPaused) return;
    
    _currentSpeed = position.speed;
    if (position.speed > _maxSpeed) {
      _maxSpeed = position.speed;
    }
    
    _currentElevation = position.altitude;
    
    onPositionUpdated?.call(position);
    
    // Add point if moved significant distance
    if (_recordedPoints.isNotEmpty) {
      final lastPoint = _recordedPoints.last;
      final distance = _calculateHaversineDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        position.latitude,
        position.longitude,
      );
      
      // Only record if moved at least 5 meters
      if (distance >= 5) {
        _addPoint(position);
      }
    } else {
      _addPoint(position);
    }
  }
  
  void _addPoint(Position position) {
    final point = GeoPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      elevation: position.altitude,
      timestamp: DateTime.now(),
    );
    
    // Calculate distance from last point
    if (_recordedPoints.isNotEmpty) {
      final lastPoint = _recordedPoints.last;
      final segmentDistance = _calculateHaversineDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );
      _totalDistance += segmentDistance;
      
      // Calculate elevation change
      if (lastPoint.elevation != null && point.elevation != null) {
        final elevDiff = point.elevation! - lastPoint.elevation!;
        if (elevDiff > 0) {
          _elevationGain += elevDiff;
        } else {
          _elevationLoss += elevDiff.abs();
        }
      }
      
      onDistanceUpdated?.call(_totalDistance);
    }
    
    _recordedPoints.add(point);
    onPointRecorded?.call(point);
  }
  
  /// Pause recording
  void pauseRecording() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
  }
  
  /// Resume recording
  void resumeRecording() {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
  }
  
  /// Stop recording and return the recorded track data
  Future<RecordedTrackData?> stopRecording() async {
    if (!_isRecording) return null;
    
    _isRecording = false;
    _isPaused = false;
    
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    
    if (_recordedPoints.isEmpty || _startTime == null) {
      return null;
    }
    
    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(_startTime!).inSeconds;
    
    return RecordedTrackData(
      points: List.from(_recordedPoints),
      startTime: _startTime!,
      endTime: endTime,
      distance: _totalDistance,
      elevationGain: _elevationGain,
      elevationLoss: _elevationLoss,
      avgSpeed: durationSeconds > 0 ? _totalDistance / durationSeconds : 0,
      maxSpeed: _maxSpeed,
      caloriesBurned: _estimateCalories(
        distanceMeters: _totalDistance,
        durationSeconds: durationSeconds,
        elevationGain: _elevationGain,
      ),
    );
  }
  
  /// Discard the current recording
  void discardRecording() {
    _isRecording = false;
    _isPaused = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _recordedPoints.clear();
    _startTime = null;
    _totalDistance = 0;
    _elevationGain = 0;
    _elevationLoss = 0;
    _maxSpeed = 0;
  }
  
  /// Estimate calories burned
  double _estimateCalories({
    required double distanceMeters,
    required int durationSeconds,
    required double elevationGain,
  }) {
    // MET (Metabolic Equivalent of Task) based estimation
    // Walking = 3.5 MET, Hiking with elevation = 6-8 MET
    
    const double weight = 70; // Average weight in kg
    
    // Calculate average MET based on speed and elevation
    final speedKmh = (distanceMeters / 1000) / (durationSeconds / 3600);
    final inclinePercent = elevationGain / distanceMeters * 100;
    
    double met;
    if (speedKmh < 4) {
      met = 2.5 + inclinePercent * 0.1;
    } else if (speedKmh < 6) {
      met = 3.5 + inclinePercent * 0.15;
    } else if (speedKmh < 8) {
      met = 5.0 + inclinePercent * 0.2;
    } else {
      met = 7.0 + inclinePercent * 0.25;
    }
    
    // Calories = MET * weight * hours
    final hours = durationSeconds / 3600;
    return met * weight * hours;
  }
  
  /// Stream position updates
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
  
  /// Calculate distance between two positions
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
  
  /// Calculate Haversine distance between two coordinates
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Data from a completed recording
class RecordedTrackData {
  final List<GeoPoint> points;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final double elevationGain;
  final double elevationLoss;
  final double avgSpeed;
  final double maxSpeed;
  final double caloriesBurned;
  
  const RecordedTrackData({
    required this.points,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.elevationGain,
    required this.elevationLoss,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.caloriesBurned,
  });
  
  Duration get duration => endTime.difference(startTime);
  
  /// Convert to RecordedTrack model
  RecordedTrack toRecordedTrack({
    required String userId,
    String? title,
    String? notes,
    String? mapSnapshotUrl,
  }) {
    return RecordedTrack(
      id: '',
      title: title,
      notes: notes,
      startTime: startTime,
      endTime: endTime,
      distance: distance,
      points: points,
      mapSnapshotUrl: mapSnapshotUrl,
      caloriesBurned: caloriesBurned,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      userId: userId,
    );
  }
}

/// Exception for location service errors
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);
  
  @override
  String toString() => 'LocationServiceException: $message';
}

/// Exception for location permission errors
class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException(this.message);
  
  @override
  String toString() => 'LocationPermissionException: $message';
}
