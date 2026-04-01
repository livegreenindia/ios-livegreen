import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/trek.dart';
import '../../services/trek_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/routing_service.dart';
import '../../services/share_image_service.dart';
import '../../widgets/trek/share_card_widget.dart';

/// Path Tracking Screen for recording treks
class PathTrackingScreen extends StatefulWidget {
  final Trek? trek; // Optional: if following a predefined trek

  const PathTrackingScreen({super.key, this.trek});

  @override
  State<PathTrackingScreen> createState() => _PathTrackingScreenState();
}

class _PathTrackingScreenState extends State<PathTrackingScreen>
    with WidgetsBindingObserver {
  final LocationTrackingService _locationService = LocationTrackingService();
  final TrekService _trekService = TrekService();
  final RoutingService _routingService = RoutingService();
  GoogleMapController? _mapController;

  // State
  bool _isInitializing = true;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _error;
  Position? _currentPosition;
  MapType _mapType = MapType.terrain;
  Trek? _trekWithRoute; // Trek with fetched route

  // Tracking data
  final List<LatLng> _recordedPath = [];
  Duration _elapsedTime = Duration.zero;
  double _distance = 0;
  double _currentElevation = 0;
  double _currentSpeed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    debugPrint('PathTrackingScreen: trek=${widget.trek?.title}, routePoints=${widget.trek?.routePoints.length}');
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation(); // This will fetch the route after location is ready
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _locationService.discardRecording();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep tracking in background
    if (state == AppLifecycleState.paused && _isRecording) {
      // App went to background, tracking continues
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground
      _updateUI();
    }
  }

  Future<void> _initializeLocation() async {
    try {
      await _locationService.checkAndRequestPermission();
      final position = await _locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentElevation = position.altitude;
          _isInitializing = false;
        });

        // Move camera to current location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            16,
          ),
        );
        
        // NOW fetch the route after we have the current position
        // Always fetch navigation route for better path display
        if (widget.trek != null) {
          _fetchTrekRoute();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitializing = false;
        });
      }
    }
  }

  /// Fetch the actual route between current location and trek destination
  Future<void> _fetchTrekRoute() async {
    if (widget.trek == null || _currentPosition == null) return;
    
    try {
      debugPrint('=== ROUTING: Starting route fetch ===');
      debugPrint('Current location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      debugPrint('Trek: ${widget.trek!.title}');
      
      final startPoint = GeoPoint(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
      
      // Use trek's start point as destination (or calculate a good destination)
      GeoPoint? endPoint;
      if (widget.trek!.startPoint != null) {
        endPoint = widget.trek!.startPoint;
        debugPrint('Using startPoint as destination: ${endPoint!.latitude}, ${endPoint.longitude}');
      } else if (widget.trek!.location != null) {
        endPoint = widget.trek!.location!.geopoint;
        debugPrint('Using location as destination: ${endPoint.latitude}, ${endPoint.longitude}');
      }
      
      if (endPoint == null) {
        debugPrint('=== ROUTING: No destination point available ===');
        _trekWithRoute = widget.trek;
        return;
      }

      // Fetch the route
      debugPrint('=== ROUTING: Calling routing service ===');
      final routePoints = await _routingService.getRouteFromPoints(startPoint, endPoint);
      
      debugPrint('=== ROUTING: Route fetched with ${routePoints.length} points ===');

      if (mounted) {
        setState(() {
          debugPrint('=== ROUTING: Updating trek with route ===');
          // Create a new trek with the fetched route points
          _trekWithRoute = Trek(
            id: widget.trek!.id,
            title: widget.trek!.title,
            description: widget.trek!.description,
            category: widget.trek!.category,
            difficulty: widget.trek!.difficulty,
            distance: widget.trek!.distance,
            estimatedTimeMinutes: widget.trek!.estimatedTimeMinutes,
            imageUrl: widget.trek!.imageUrl,
            elevationProfile: widget.trek!.elevationProfile,
            elevationGain: widget.trek!.elevationGain,
            elevationLoss: widget.trek!.elevationLoss,
            minElevation: widget.trek!.minElevation,
            maxElevation: widget.trek!.maxElevation,
            routePoints: routePoints, // Use fetched route
            startPoint: widget.trek!.startPoint,
            endPoint: widget.trek!.endPoint,
            location: widget.trek!.location,
            createdAt: widget.trek!.createdAt,
            updatedAt: widget.trek!.updatedAt,
            usersToday: widget.trek!.usersToday,
            rating: widget.trek!.rating,
            reviewCount: widget.trek!.reviewCount,
            isPublic: widget.trek!.isPublic,
            tags: widget.trek!.tags,
          );
          debugPrint('=== ROUTING: Trek updated, polylines should rebuild ===');
        });

        // Auto-fit map to show the entire route like Google Maps
        Future.delayed(const Duration(milliseconds: 300), () {
          final bounds = _getRouteBounds();
          if (bounds != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100), // 100px padding
            );
            debugPrint('=== MAP: Animated camera to route bounds ===');
          }
        });
      }
    } catch (e) {
      debugPrint('=== ROUTING: Error fetching route: $e ===');
      // Fallback: use original trek
      _trekWithRoute = widget.trek;
    }
  }

  void _startRecording() async {
    // Show prominent disclosure for background location (required by Google Play)
    final confirmed = await _showBackgroundLocationDisclosure();
    if (!confirmed) return;
    
    try {
      await _locationService.startRecording();

      // Set up callbacks
      _locationService.onPointRecorded = (point) {
        if (mounted) {
          setState(() {
            _recordedPath.add(LatLng(point.latitude, point.longitude));
          });
          // Animate camera to follow user
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(point.latitude, point.longitude)),
          );
        }
      };

      _locationService.onDistanceUpdated = (distance) {
        if (mounted) setState(() => _distance = distance);
      };

      _locationService.onPositionUpdated = (position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _currentElevation = position.altitude;
            _currentSpeed = position.speed;
          });
        }
      };

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isRecording && !_isPaused) {
          setState(() {
            _elapsedTime = _locationService.elapsedTime;
          });
        }
      });

      setState(() {
        _isRecording = true;
        _isPaused = false;
      });

      // Haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  void _pauseRecording() {
    _locationService.pauseRecording();
    setState(() => _isPaused = true);
    HapticFeedback.lightImpact();
  }

  void _resumeRecording() {
    _locationService.resumeRecording();
    setState(() => _isPaused = false);
    HapticFeedback.lightImpact();
  }

  Future<void> _stopRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text('Do you want to save this track?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _saveTrack();
    } else if (confirmed == false) {
      _discardRecording();
    }
  }

  Future<void> _saveTrack() async {
    final trackData = await _locationService.stopRecording();
    _timer?.cancel();

    if (trackData == null || trackData.points.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No track data to save')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Show save dialog
    if (!mounted) return;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _SaveTrackDialog(
        distance: trackData.distance,
        duration: trackData.duration,
      ),
    );

    if (result != null) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final track = trackData.toRecordedTrack(
          userId: userId,
          title: result['title'],
          notes: result['notes'],
        );
        await _trekService.saveRecordedTrack(track);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Track saved successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save track: $e')),
          );
        }
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  /// Show prominent disclosure for background location access (required by Google Play)
  Future<bool> _showBackgroundLocationDisclosure() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_on, color: Colors.green, size: 48),
        title: const Text('Location Access Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To record your trek accurately, LiveGreen needs to access your location continuously.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Text(
              'This includes when the app is in the background, so your route is tracked even if you:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.camera_alt, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('Take photos during your trek'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.message, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('Check messages briefly'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.music_note, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('Control music playback'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'A notification will show your recording status. You can stop recording at any time.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Recording'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _discardRecording() {
    _locationService.discardRecording();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordedPath.clear();
      _elapsedTime = Duration.zero;
      _distance = 0;
    });
  }

  void _updateUI() {
    if (_isRecording) {
      setState(() {
        _elapsedTime = _locationService.elapsedTime;
        _distance = _locationService.totalDistance;
      });
    }
  }

  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16,
        ),
      );
    }
    HapticFeedback.selectionClick();
  }

  void _toggleMapType() {
    // Cycle through map types: Normal -> Terrain -> Satellite -> Normal
    setState(() {
      switch (_mapType) {
        case MapType.normal:
          _mapType = MapType.terrain;
          break;
        case MapType.terrain:
          _mapType = MapType.satellite;
          break;
        case MapType.satellite:
          _mapType = MapType.normal;
          break;
        default:
          _mapType = MapType.normal;
      }
    });
    HapticFeedback.selectionClick();
  }

  /// Get appropriate icon based on current map type
  IconData _getMapTypeIcon() {
    switch (_mapType) {
      case MapType.normal:
        return Icons.map;
      case MapType.terrain:
        return Icons.terrain;
      case MapType.satellite:
        return Icons.satellite;
      default:
        return Icons.map;
    }
  }

  /// Calculate bounds to fit entire route on map
  LatLngBounds? _getRouteBounds() {
    final trek = _trekWithRoute ?? widget.trek;
    if (trek == null || trek.routePoints.isEmpty) return null;

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final point in trek.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    // Use trek with fetched route, or original trek
    final trek = _trekWithRoute ?? widget.trek;
    
    debugPrint('=== POLYLINES: Building polylines, trek=${trek?.title}, _trekWithRoute=${_trekWithRoute?.title} ===');
    
    // Show the planned navigation route (blue line)
    // Skip drawing if it's just a straight line (2 points or less) as it's not helpful
    if (trek != null && trek.routePoints.length > 2) {
      final points = trek.routePoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      debugPrint('=== POLYLINES: Trek has ${points.length} route points, creating polyline ===');
      polylines.add(Polyline(
        polylineId: const PolylineId('trek_route'),
        points: points,
        color: const Color(0xFF2196F3), // Bright blue - navigation route
        width: 6,
      ));
    }

    // Recorded path - Bold green (your actual path while recording)
    if (_recordedPath.isNotEmpty && _recordedPath.length > 1) {
      debugPrint('=== POLYLINES: Adding recorded path with ${_recordedPath.length} points ===');
      polylines.add(Polyline(
        polylineId: const PolylineId('recorded_path'),
        points: _recordedPath,
        color: const Color(0xFF4CAF50), // Bright green - actual path
        width: 10,
      ));
    }

    debugPrint('=== POLYLINES: Total polylines built: ${polylines.length} ===');
    return polylines;
  }

  Set<Polygon> _buildPolygons() {
    // Polygons disabled - using Polylines only to avoid duplicate route lines
    return {};
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final trek = _trekWithRoute ?? widget.trek;

    // User location marker
    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    // Trek start point
    if (trek != null && trek.startPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('trek_start'),
        position: LatLng(trek.startPoint!.latitude, trek.startPoint!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: '🟢 Start: ${trek.title}',
          snippet: '${trek.startPoint!.latitude.toStringAsFixed(4)}, ${trek.startPoint!.longitude.toStringAsFixed(4)}',
        ),
      ));
    }

    // Trek end point
    if (trek != null && trek.endPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('trek_end'),
        position: LatLng(trek.endPoint!.latitude, trek.endPoint!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: '🔴 End Point',
          snippet: '${trek.endPoint!.latitude.toStringAsFixed(4)}, ${trek.endPoint!.longitude.toStringAsFixed(4)}',
        ),
      ));
    }

    // Recording start marker
    if (_recordedPath.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('recording_start'),
        position: _recordedPath.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Recording Started'),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          _buildMap(),

          // Loading overlay
          if (_isInitializing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: AppSpacing.lg),
                    Text(
                      'Getting your location...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Error overlay
          if (_error != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off, color: Colors.white, size: 64),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Location Error',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isInitializing = true;
                          });
                          _initializeLocation();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top stats card
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _buildStatsCard(),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            left: AppSpacing.md,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: colorScheme.surface.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),

          // Right side controls
          Positioned(
            right: AppSpacing.lg,
            bottom: 160,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.my_location,
                  onPressed: _centerOnUser,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MapControlButton(
                  icon: _getMapTypeIcon(),
                  onPressed: _toggleMapType,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MapControlButton(
                  icon: Icons.layers,
                  onPressed: () {
                    // Fit route in view
                    final bounds = _getRouteBounds();
                    if (bounds != null && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 100),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final initialPosition = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : widget.trek?.startPoint != null
            ? LatLng(widget.trek!.startPoint!.latitude, widget.trek!.startPoint!.longitude)
            : const LatLng(20.5937, 78.9629);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 13,
        // No tilt - keep flat view so polylines are clearly visible
      ),
      mapType: _mapType,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      polylines: _buildPolylines(),
      polygons: _buildPolygons(),
      markers: _buildMarkers(),
      onMapCreated: (controller) {
        _mapController = controller;
        // Fit the entire route in view when trek is loaded
        final trek = _trekWithRoute ?? widget.trek;
        if (trek != null && trek.routePoints.isNotEmpty && trek.routePoints.length > 1) {
          Future.delayed(const Duration(milliseconds: 300), () {
            final bounds = _getRouteBounds();
            if (bounds != null && mounted) {
              try {
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds, 100),
                );
              } catch (e) {
                debugPrint('Error animating camera: $e');
              }
            }
          });
        }
      },
    );
  }

  Widget _buildStatsCard() {
    return AnimatedOpacity(
      opacity: _isRecording ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(left: 50), // Leave space for back button
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: 'Time',
              value: _formatDuration(_elapsedTime),
              icon: Icons.timer,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white24,
            ),
            _StatItem(
              label: 'Distance',
              value: _formatDistance(_distance),
              icon: Icons.straighten,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white24,
            ),
            _StatItem(
              label: 'Elevation',
              value: '${_currentElevation.toInt()} m',
              icon: Icons.terrain,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white24,
            ),
            _StatItem(
              label: 'Speed',
              value: '${_currentSpeed.toStringAsFixed(1)} m/s',
              icon: Icons.speed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final hasRecording = _recordedPath.isNotEmpty;
    final trek = _trekWithRoute ?? widget.trek;
    final hasTrekRoute = trek != null && trek.routePoints.length > 2;

    if (!hasTrekRoute && !hasRecording) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (hasTrekRoute)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Follow the suggested route',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hasTrekRoute)
            _LegendItem(
              color: AppColors.primary.withOpacity(0.7),
              label: 'Suggested Route (Follow this path)',
              width: 6,
            ),
          if (hasTrekRoute && hasRecording)
            const SizedBox(height: AppSpacing.sm),
          if (hasRecording)
            _LegendItem(
              color: AppColors.success,
              label: 'Your Recording (Actual path taken)',
              width: 8,
            ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          _LegendItem(
            emoji: '🟢',
            label: 'Start Point',
            width: 0,
          ),
          _LegendItem(
            emoji: '🔴',
            label: 'End Point',
            width: 0,
          ),
          _LegendItem(
            emoji: '🔵',
            label: 'Your Location',
            width: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: _isRecording ? _buildRecordingControls() : _buildStartControl(),
      ),
    );
  }

  Widget _buildStartControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.trek != null) ...[
          Text(
            'Following: ${widget.trek!.title}',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _isInitializing ? null : _startRecording,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Recording'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Pause/Resume button
        _RecordingButton(
          icon: _isPaused ? Icons.play_arrow : Icons.pause,
          label: _isPaused ? 'Resume' : 'Pause',
          color: AppColors.warning,
          onPressed: _isPaused ? _resumeRecording : _pauseRecording,
        ),
        // Stop button
        _RecordingButton(
          icon: Icons.stop,
          label: 'Stop',
          color: AppColors.error,
          onPressed: _stopRecording,
          large: true,
        ),
        // Discard button
        _RecordingButton(
          icon: Icons.delete_outline,
          label: 'Discard',
          color: Colors.grey,
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard Recording?'),
                content: const Text('This will delete all recorded data.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (confirmed == true) _discardRecording();
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _MapControlButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _RecordingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool large;

  const _RecordingButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 72 : 56,
          height: large ? 72 : 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, size: large ? 32 : 24),
            onPressed: onPressed,
            style: IconButton.styleFrom(foregroundColor: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SaveTrackDialog extends StatefulWidget {
  final double distance;
  final Duration duration;

  const _SaveTrackDialog({
    required this.distance,
    required this.duration,
  });

  @override
  State<_SaveTrackDialog> createState() => _SaveTrackDialogState();
}

class _SaveTrackDialogState extends State<_SaveTrackDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  // Share Card variables
  String? _selectedImagePath;
  final GlobalKey _shareCardKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  bool _isGeneratingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    final titleString = _titleController.text.isEmpty
        ? 'Morning Trek'
        : _titleController.text;
    final dateString = DateFormat('MMM d, y • h:mm a').format(DateTime.now());
    final paceString = ((widget.distance / 1000) / max(widget.duration.inSeconds / 3600, 0.001)).toStringAsFixed(1) + ' km/h';

    return AlertDialog(
      title: const Text('Save Track'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats summary
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        _formatDistance(widget.distance),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Distance',
                        style: GoogleFonts.manrope(fontSize: 11),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        _formatDuration(widget.duration),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Duration',
                        style: GoogleFonts.manrope(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'Morning walk, etc.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}), // Refresh preview
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any notes about this track...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            
            Text(
              'Share Preview',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Share Card Preview
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280), // Dialog visual preview size
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _shareCardKey,
                    child: SizedBox(
                      width: 800, // Fixed logical width for high-resolution layout and scaled fonts
                      child: ShareCardWidget(
                        boundaryKey: GlobalKey(), // the RepaintBoundary is now wrapped outside
                        title: titleString,
                        distance: _formatDistance(widget.distance),
                        duration: _formatDuration(widget.duration),
                        speed: paceString,
                        elevation: '0 m', // Can be parameterized if needed
                        date: dateString,
                        backgroundImagePath: _selectedImagePath,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Photo actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Take Photo'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                if (_selectedImagePath != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => setState(() => _selectedImagePath = null),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: _isGeneratingImage ? null : () async {
            setState(() {
              _isGeneratingImage = true;
            });
            
            final title = _titleController.text.isEmpty
                ? 'Track ${DateTime.now().toString().substring(0, 16)}'
                : _titleController.text;
            final notes = _notesController.text;
            
            final textMessage = '🏃 Trek Completed! 🏃\n\n'
                '📍 $title\n\n'
                '${notes.isNotEmpty ? "\n📝 Notes: $notes\n" : ""}'
                '\nDownload LiveGreen to track your treks!\n'
                'https://play.google.com/store/apps/details?id=com.livegreen.app';
                
            await ShareImageService.captureAndShare(
              boundaryKey: _shareCardKey,
              subject: title,
              text: textMessage,
            );
            
            if (mounted) {
              setState(() {
                _isGeneratingImage = false;
              });
            }
          },
          icon: _isGeneratingImage 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.share),
          label: _isGeneratingImage ? const Text('Sharing...') : const Text('Share'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'title': _titleController.text.isEmpty
                  ? 'Track ${DateTime.now().toString().substring(0, 16)}'
                  : _titleController.text,
              'notes': _notesController.text,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
/// Legend item widget for map legend display
class _LegendItem extends StatelessWidget {
  final String? emoji;
  final String label;
  final Color? color;
  final int width;

  const _LegendItem({
    this.emoji,
    required this.label,
    this.color,
    this.width = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (emoji != null) {
      // Marker legend item
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji!,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      // Polyline legend item
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }
}