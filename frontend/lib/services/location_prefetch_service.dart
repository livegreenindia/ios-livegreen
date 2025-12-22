import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'osm_trek_service.dart';

/// Service to handle location permission with user-friendly dialog
/// and prefetch OSM data in background for better UX
class LocationPrefetchService {
  static final LocationPrefetchService _instance = LocationPrefetchService._internal();
  factory LocationPrefetchService() => _instance;
  LocationPrefetchService._internal();

  bool _hasInitialized = false;
  bool _permissionGranted = false;
  Position? _lastPosition;
  static const String _prefetchedKey = 'osm_prefetched_location';
  
  bool get hasLocationPermission => _permissionGranted;
  Position? get lastKnownPosition => _lastPosition;

  /// Initialize location permission with user-friendly dialog
  /// Call this after app starts and context is available
  /// Now shows dialog for all users (like notifications) and prefetches OSM data
  static Future<void> initializeWithDialog(BuildContext context) async {
    final service = LocationPrefetchService();
    await service._initializeWithContext(context);
  }

  /// Simple location permission request (just system dialog, no custom UI)
  static Future<void> requestBasicPermission(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show simple service disabled message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services in your device settings'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission (shows system dialog)
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required for exploration features'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else if (permission == LocationPermission.deniedForever) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission denied. Enable in settings to use exploration features.'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => Geolocator.openAppSettings(),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Location] Error requesting permission: $e');
    }
  }

  Future<void> _initializeWithContext(BuildContext context) async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationPrefetch] Location services disabled');
        return;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Show explanation dialog before requesting permission
        if (context.mounted) {
          final shouldRequest = await _showLocationExplanationDialog(context);
          if (!shouldRequest) {
            debugPrint('[LocationPrefetch] User declined to grant location');
            return;
          }
        }
        
        // Request permission
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        _permissionGranted = true;
        debugPrint('[LocationPrefetch] Location permission granted - starting background OSM data prefetch');
        
        // Start background prefetch - simplified version without OSM
      _prefetchBasicLocationData();
      } else if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationPrefetch] Location permanently denied');
        if (context.mounted) {
          _showSettingsDialog(context);
        }
      }
    } catch (e) {
      debugPrint('[LocationPrefetch] Error: $e');
    }
  }

  /// Show user-friendly bottom modal explaining why location is needed
  Future<bool> _showLocationExplanationDialog(BuildContext context) async {
    bool isLoading = false;

    return await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Enable Location Services',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'LiveGreen needs your location to provide location-based features:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                // Feature list
                _buildFeatureRow(
                  Icons.location_on,
                  'Show your current location on maps',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  Icons.directions_run,
                  'Track your outdoor activities',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  Icons.navigation,
                  'Get directions and navigation',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  Icons.explore,
                  'Discover location-based content',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  Icons.offline_pin,
                  'Enable offline location features',
                ),
                const SizedBox(height: 24),

                // Privacy note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your location data is only used to enhance your experience and is never shared. Location information is stored locally on your device.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isLoading ? null : () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Not Now',
                          style: TextStyle(
                            color: isLoading ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setState(() => isLoading = true);
                                // Small delay to show loading state
                                await Future.delayed(const Duration(milliseconds: 500));
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLoading ? Colors.grey[400] : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Enable Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ) ?? false;
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  /// Show bottom modal when permission is permanently denied
  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.location_off, color: Colors.orange, size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Location Access Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              const Text(
                'Location access has been permanently denied. To use location features like finding nearby places and pre-loading map data, please enable location in your device settings.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Geolocator.openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Prefetch basic location data (no external API calls)
  Future<void> _prefetchBasicLocationData() async {
    try {
      // Just get and cache current position
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (_lastPosition == null) {
        debugPrint('[LocationPrefetch] Could not get position for basic caching');
        return;
      }

      // Cache location for future use
      final prefs = await SharedPreferences.getInstance();
      final currentKey = '${_lastPosition!.latitude.toStringAsFixed(2)}_${_lastPosition!.longitude.toStringAsFixed(2)}';
      await prefs.setString(_prefetchedKey, currentKey);

      debugPrint('[LocationPrefetch] Basic location cached - ready for location-based features');
      
    } catch (e) {
      debugPrint('[LocationPrefetch] Basic location caching error: $e');
    }
  }

  /// Force refresh OSM data (can be called manually if needed)
  Future<void> refreshOSMData() async {
    if (!_permissionGranted) return;
    
    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      if (_lastPosition != null) {
        // Clear the prefetch key to force refresh
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefetchedKey);
        await _prefetchBasicLocationData();
      }
    } catch (e) {
      debugPrint('[LocationPrefetch] Refresh error: $e');
    }
  }
}

/// Alternative: For future implementation with Google Places API
/// This would provide accurate, fast location data but requires API setup
/*
Future<List<Map<String, dynamic>>> fetchPlacesWithGoogleAPI({
  required double latitude,
  required double longitude,
  String type = 'gym|park|trail',
  int radius = 5000,
}) async {
  // Implementation would use Google Places API
  // - Much faster than OSM (typically < 1 second)
  // - More accurate and up-to-date data
  // - Better categorization and rich information
  // - Requires API key and billing setup ($200 free credit)
  // - Rate limits: 20 requests per second, 150,000 per month free
}
*/
