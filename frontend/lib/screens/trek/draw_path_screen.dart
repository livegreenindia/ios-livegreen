import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/trek.dart';
import '../../services/trek_service.dart';
import '../../services/place_submission_service.dart';
import '../../services/location_tracking_service.dart';

/// Draw Path Screen - allows users to draw custom routes on a map
class DrawPathScreen extends StatefulWidget {
  const DrawPathScreen({super.key});

  @override
  State<DrawPathScreen> createState() => _DrawPathScreenState();
}

class _DrawPathScreenState extends State<DrawPathScreen> {
  final LocationTrackingService _locationService = LocationTrackingService();
  GoogleMapController? _mapController;

  // State
  bool _isInitializing = true;
  String? _error;
  Position? _currentPosition;
  MapType _mapType = MapType.normal;
  bool _isSaving = false;

  // Drawing state
  final List<LatLng> _pathPoints = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Selected category for the path
  TrekCategory _selectedCategory = TrekCategory.natureWalk;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _locationService.checkAndRequestPermission();
      final position = await _locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isInitializing = false;
        });

        // Move camera to current location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
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

  void _onMapTap(LatLng position) {
    setState(() {
      _pathPoints.add(position);
      _updateMarkersAndPolylines();
    });
  }

  void _updateMarkersAndPolylines() {
    // Create markers for each point
    _markers = _pathPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      final isFirst = index == 0;
      final isLast = index == _pathPoints.length - 1;
      
      return Marker(
        markerId: MarkerId('point_$index'),
        position: point,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isFirst 
              ? BitmapDescriptor.hueGreen 
              : isLast 
                  ? BitmapDescriptor.hueRed 
                  : BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: isFirst ? 'Start' : isLast ? 'End' : 'Point ${index + 1}',
          snippet: 'Tap to remove',
        ),
        onTap: () => _showRemovePointDialog(index),
      );
    }).toSet();

    // Create polyline connecting all points
    if (_pathPoints.length > 1) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('drawn_path'),
          points: _pathPoints,
          color: _getCategoryColor(_selectedCategory),
          width: 4,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ),
      };
    } else {
      _polylines = {};
    }
  }

  void _showRemovePointDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Point'),
        content: Text('Remove point ${index + 1} from the path?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pathPoints.removeAt(index);
                _updateMarkersAndPolylines();
              });
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _undoLastPoint() {
    if (_pathPoints.isNotEmpty) {
      setState(() {
        _pathPoints.removeLast();
        _updateMarkersAndPolylines();
      });
    }
  }

  void _clearAllPoints() {
    if (_pathPoints.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Points'),
        content: const Text('Remove all points from the path?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _pathPoints.clear();
                _updateMarkersAndPolylines();
              });
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  double _calculateTotalDistance() {
    if (_pathPoints.length < 2) return 0;
    
    double total = 0;
    for (int i = 0; i < _pathPoints.length - 1; i++) {
      total += _calculateDistance(_pathPoints[i], _pathPoints[i + 1]);
    }
    return total;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // meters
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final dLon = (p2.longitude - p1.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }

  int _estimateTime(double distanceMeters) {
    // Estimate walking time at ~5 km/h
    final hours = distanceMeters / 5000;
    return (hours * 60).round();
  }

  Future<void> _savePath() async {
    if (_pathPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 points to create a path')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _SavePathDialog(
        distance: _calculateTotalDistance(),
        pointCount: _pathPoints.length,
        initialCategory: _selectedCategory,
      ),
    );

    if (result == null) return;

    setState(() => _isSaving = true);

    try {
      final distance = _calculateTotalDistance();
      
      // Convert LatLng to GeoPoint
      final routePoints = _pathPoints.map((p) => GeoPoint(
        latitude: p.latitude,
        longitude: p.longitude,
      )).toList();

      final startPoint = routePoints.first;

      // Import PlaceSubmissionService at the top of the file
      final placeSubmissionService = PlaceSubmissionService();
      
      // Submit to pendingPlaces for admin approval
      await placeSubmissionService.submitPlace(
        title: result['title'] as String,
        description: result['description'] as String,
        category: result['category'] as TrekCategory,
        latitude: startPoint.latitude,
        longitude: startPoint.longitude,
        routePoints: routePoints,
        distance: distance,
        difficulty: result['difficulty'] as TrekDifficulty,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Path submitted for admin approval!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save path: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _getCategoryColor(TrekCategory category) {
    switch (category) {
      case TrekCategory.trekkingPoint:
        return Colors.brown;
      case TrekCategory.natureWalk:
        return AppColors.success;
      case TrekCategory.cyclePath:
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distance = _calculateTotalDistance();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Draw Path',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        actions: [
          // Map type toggle
          IconButton(
            icon: Icon(_mapType == MapType.normal ? Icons.satellite : Icons.map),
            tooltip: 'Toggle map type',
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.normal 
                    ? MapType.satellite 
                    : MapType.normal;
              });
            },
          ),
          // Clear all
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear all points',
            onPressed: _pathPoints.isEmpty ? null : _clearAllPoints,
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildMapView(),
      bottomNavigationBar: _buildBottomBar(distance),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isInitializing = true;
                });
                _initializeLocation();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        // Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(0, 0),
            zoom: 15,
          ),
          mapType: _mapType,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (controller) {
            _mapController = controller;
            if (_currentPosition != null) {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  15,
                ),
              );
            }
          },
          onTap: _onMapTap,
        ),

        // Instructions overlay
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.md,
          right: AppSpacing.md,
          child: Card(
            color: (Theme.of(context).brightness == Brightness.dark 
                ? AppColors.surfaceDark 
                : Colors.white).withOpacity(0.95),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _pathPoints.isEmpty
                          ? 'Tap on the map to add waypoints'
                          : '${_pathPoints.length} points • Tap to add more',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Category selector
        Positioned(
          top: 80,
          right: AppSpacing.md,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DropdownButton<TrekCategory>(
                value: _selectedCategory,
                underline: const SizedBox(),
                items: [
                  TrekCategory.natureWalk,
                  TrekCategory.trekkingPoint,
                  TrekCategory.cyclePath,
                ].map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getCategoryIcon(cat), size: 18, color: _getCategoryColor(cat)),
                      const SizedBox(width: 8),
                      Text(cat.displayName, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedCategory = v;
                      _updateMarkersAndPolylines();
                    });
                  }
                },
              ),
            ),
          ),
        ),

        // My location button
        Positioned(
          bottom: AppSpacing.lg,
          right: AppSpacing.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Undo button
              if (_pathPoints.isNotEmpty)
                FloatingActionButton.small(
                  heroTag: 'undo',
                  onPressed: _undoLastPoint,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.undo, color: Colors.white),
                ),
              const SizedBox(height: AppSpacing.sm),
              // My location
              FloatingActionButton.small(
                heroTag: 'location',
                onPressed: () {
                  if (_currentPosition != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(TrekCategory category) {
    switch (category) {
      case TrekCategory.trekkingPoint:
        return Icons.terrain;
      case TrekCategory.natureWalk:
        return Icons.directions_run;
      case TrekCategory.cyclePath:
        return Icons.directions_bike;
      default:
        return Icons.place;
    }
  }

  Widget _buildBottomBar(double distance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: _formatDistance(distance),
                ),
                _StatItem(
                  icon: Icons.pin_drop,
                  label: 'Points',
                  value: '${_pathPoints.length}',
                ),
                _StatItem(
                  icon: Icons.schedule,
                  label: 'Est. Time',
                  value: '${_estimateTime(distance)} min',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pathPoints.length >= 2 && !_isSaving ? _savePath : null,
                icon: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Path'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// Dialog for saving the drawn path
class _SavePathDialog extends StatefulWidget {
  final double distance;
  final int pointCount;
  final TrekCategory initialCategory;

  const _SavePathDialog({
    required this.distance,
    required this.pointCount,
    required this.initialCategory,
  });

  @override
  State<_SavePathDialog> createState() => _SavePathDialogState();
}

class _SavePathDialogState extends State<_SavePathDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late TrekCategory _category;
  TrekDifficulty _difficulty = TrekDifficulty.moderate;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.save, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          const Text('Save Path'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
                          ),
                        ),
                        const Text('Distance', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${widget.pointCount}',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Points', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Path Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Category
              DropdownButtonFormField<TrekCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  TrekCategory.natureWalk,
                  TrekCategory.trekkingPoint,
                  TrekCategory.cyclePath,
                ].map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat.displayName),
                )).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Difficulty
              DropdownButtonFormField<TrekDifficulty>(
                value: _difficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: TrekDifficulty.values.map((diff) => DropdownMenuItem(
                  value: diff,
                  child: Text(diff.displayName),
                )).toList(),
                onChanged: (v) => setState(() => _difficulty = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'title': _titleController.text.trim(),
                'description': _descriptionController.text.trim(),
                'category': _category,
                'difficulty': _difficulty,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
