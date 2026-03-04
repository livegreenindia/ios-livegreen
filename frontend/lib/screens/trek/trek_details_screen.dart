import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../models/trek.dart';
import '../../services/trek_service.dart';
import '../../services/location_tracking_service.dart';
import '../../widgets/trek/trek_components.dart';
import 'path_tracking_screen.dart';

/// Trek Details Screen with map, elevation profile, and reviews
class TrekDetailsScreen extends StatefulWidget {
  final Trek trek;

  const TrekDetailsScreen({super.key, required this.trek});

  @override
  State<TrekDetailsScreen> createState() => _TrekDetailsScreenState();
}

class _TrekDetailsScreenState extends State<TrekDetailsScreen> {
  final TrekService _trekService = TrekService();
  final LocationTrackingService _locationService = LocationTrackingService();
  GoogleMapController? _mapController;
  bool _isFavorite = false;
  List<TrekReview> _reviews = [];
  bool _isLoadingReviews = true;
  Position? _currentPosition;

  // Directions API route
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

  static const String _mapsApiKey = 'AIzaSyA59STvjWZcL-k_gipSGBDV6u797zF0Q9M';

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _loadReviews();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      await _locationService.checkAndRequestPermission();
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() => _currentPosition = position);
        // Fetch real road route once we have the user's location
        if (widget.trek.startPoint != null) {
          _fetchDirections(position);
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  /// Calls Google Directions API and stores decoded polyline points.
  Future<void> _fetchDirections(Position from) async {
    if (widget.trek.startPoint == null) return;
    setState(() => _isLoadingRoute = true);

    final dest = widget.trek.startPoint!;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${from.latitude},${from.longitude}'
      '&destination=${dest.latitude},${dest.longitude}'
      '&mode=driving'
      '&key=$_mapsApiKey',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final encoded = routes[0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encoded);
          if (mounted) setState(() => _routePoints = points);

          // Fit camera to show full route
          if (_mapController != null && points.isNotEmpty) {
            final bounds = _boundsFromLatLngs([
              LatLng(from.latitude, from.longitude),
              ...points,
            ]);
            await Future.delayed(const Duration(milliseconds: 300));
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 60),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Directions API error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  /// Decodes a Google Maps encoded polyline string into LatLng points.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += dLat;

      result = 0; shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngs(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final isFav = await _trekService.isFavorite(widget.trek.id);
      if (mounted) setState(() => _isFavorite = isFav);
    } catch (e) {
      // Ignore error for unauthenticated users
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _trekService.getTrekReviews(widget.trek.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save favorites')),
        );
      }
      return;
    }

    // Optimistically update UI
    final wasLiked = _isFavorite;
    setState(() => _isFavorite = !_isFavorite);

    try {
      if (wasLiked) {
        await _trekService.removeFromFavorites(widget.trek.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await _trekService.addToFavorites(widget.trek.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites ❤️'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() => _isFavorite = wasLiked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorites: $e')),
        );
      }
    }
  }

  Future<void> _showAddReviewDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add a review')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddReviewDialog(),
    );

    if (result != null && mounted) {
      try {
        final review = TrekReview(
          id: '',
          trekId: widget.trek.id,
          userId: user.uid,
          userName: user.displayName ?? 'Anonymous',
          userAvatarUrl: user.photoURL,
          rating: result['rating'] as double,
          comment: result['comment'] as String?,
          photoUrls: [],
          createdAt: DateTime.now(),
        );
        
        await _trekService.addReview(review);
        await _loadReviews(); // Refresh reviews
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review added successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add review: $e')),
          );
        }
      }
    }
  }

  void _openFullscreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenMapScreen(
          trek: widget.trek,
          currentPosition: _currentPosition,
        ),
      ),
    );
  }

  /// Opens Google Maps navigation to this trekking spot.
  Future<void> _openDirections() async {
    if (widget.trek.startPoint == null) return;
    final lat = widget.trek.startPoint!.latitude;
    final lng = widget.trek.startPoint!.longitude;
    final name = Uri.encodeComponent(widget.trek.title);

    // Try Google Maps app first, fall back to browser
    final gmmIntent = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final gmmBrowser = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name&travelmode=driving');

    if (await canLaunchUrl(gmmIntent)) {
      await launchUrl(gmmIntent);
    } else {
      await launchUrl(gmmBrowser, mode: LaunchMode.externalApplication);
    }
  }

  void _startPath() {
    // Increment users today
    _trekService.incrementUsersToday(widget.trek.id);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PathTrackingScreen(trek: widget.trek),
      ),
    );
  }

  Set<Polyline> _buildPolylines() {
    if (widget.trek.routePoints.isEmpty) {
      debugPrint('Trek details polyline: No route points');
      return {};
    }

    final points = widget.trek.routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    
    debugPrint('Trek details polyline: ${points.length} points');

    return {
      // Main route polyline - Bold and very visible
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF2196F3), // Bright blue
        width: 8,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final isGooglePlace = widget.trek.routePoints.isEmpty &&
        widget.trek.startPoint != null;

    if (isGooglePlace) {
      // Single prominent location pin for Google Places treks
      markers.add(Marker(
        markerId: const MarkerId('place'),
        position: LatLng(
          widget.trek.startPoint!.latitude,
          widget.trek.startPoint!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: widget.trek.title,
          snippet: 'Tap for directions',
          onTap: _openDirections,
        ),
      ));
      return markers;
    }

    if (widget.trek.startPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(
          widget.trek.startPoint!.latitude,
          widget.trek.startPoint!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: '🟢 Trek Start',
          snippet: '${widget.trek.startPoint!.latitude.toStringAsFixed(4)}, ${widget.trek.startPoint!.longitude.toStringAsFixed(4)}',
        ),
      ));
    }

    if (widget.trek.endPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(
          widget.trek.endPoint!.latitude,
          widget.trek.endPoint!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: '🔴 Trek End',
          snippet: '${widget.trek.endPoint!.latitude.toStringAsFixed(4)}, ${widget.trek.endPoint!.longitude.toStringAsFixed(4)}',
        ),
      ));
    }

    return markers;
  }

  LatLngBounds? _getMapBounds() {
    if (widget.trek.routePoints.isEmpty) return null;

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final point in widget.trek.routePoints) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Hero image with parallax
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  widget.trek.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.trek.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.primary.withOpacity(0.3),
                          child: const Icon(
                            Icons.terrain,
                            size: 100,
                            color: Colors.white54,
                          ),
                        ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Title and category
                  Positioned(
                    bottom: AppSpacing.lg,
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DifficultyChip(difficulty: widget.trek.difficulty),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.trek.title,
                          style: GoogleFonts.manrope(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? AppColors.error : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  Share.share(
                    '${widget.trek.title}\n\n'
                    '${widget.trek.description}\n\n'
                    'Distance: ${widget.trek.formattedDistance}\n'
                    'Est. Time: ${widget.trek.formattedTime}\n'
                    'Difficulty: ${widget.trek.difficulty.name}\n\n'
                    'Explore this place on LiveGreen!',
                    subject: widget.trek.title,
                  );
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview stats
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: TrekStatCard(
                          icon: Icons.straighten,
                          label: 'Length',
                          value: widget.trek.formattedDistance,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TrekStatCard(
                          icon: Icons.schedule,
                          label: 'Est. Time',
                          value: widget.trek.formattedTime,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TrekStatCard(
                          icon: Icons.trending_up,
                          label: 'Elevation',
                          value: widget.trek.formattedElevationGain,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.trek.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Map section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.trek.routePoints.isEmpty
                                ? 'Location Map'
                                : 'Route Map',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Row(
                            children: [
                              if (widget.trek.routePoints.isEmpty &&
                                  widget.trek.startPoint != null)
                                TextButton.icon(
                                  onPressed: _openDirections,
                                  icon: const Icon(Icons.directions, size: 18),
                                  label: const Text('Directions'),
                                ),
                              TextButton.icon(
                                onPressed: _openFullscreenMap,
                                icon: const Icon(Icons.fullscreen, size: 18),
                                label: const Text('Fullscreen'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            width: constraints.maxWidth,
                            height: 250,
                            child: _buildMap(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Elevation profile
                if (widget.trek.elevationProfile.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elevation Profile',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildElevationChart(),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ElevationStat(
                              label: 'Min',
                              value: '${widget.trek.minElevation.toInt()} m',
                              icon: Icons.arrow_downward,
                              color: AppColors.info,
                            ),
                            _ElevationStat(
                              label: 'Max',
                              value: '${widget.trek.maxElevation.toInt()} m',
                              icon: Icons.arrow_upward,
                              color: AppColors.error,
                            ),
                            _ElevationStat(
                              label: 'Gain',
                              value: '+${widget.trek.elevationGain.toInt()} m',
                              icon: Icons.trending_up,
                              color: AppColors.success,
                            ),
                            _ElevationStat(
                              label: 'Loss',
                              value: '-${widget.trek.elevationLoss.toInt()} m',
                              icon: Icons.trending_down,
                              color: AppColors.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // Reviews section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Reviews',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              RatingStars(rating: widget.trek.rating),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '(${widget.trek.reviewCount})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _showAddReviewDialog,
                            icon: const Icon(Icons.rate_review, size: 18),
                            label: const Text('Add Review'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildReviewsSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 120), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildStartButton(),
    );
  }

  Widget _buildMap() {
    final isGooglePlace = widget.trek.routePoints.isEmpty &&
        widget.trek.startPoint != null;

    final initialPosition = widget.trek.startPoint != null
        ? LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude)
        : const LatLng(20.5937, 78.9629);

    final zoom = isGooglePlace ? 14.5 : 12.0;

    // Build polylines: driving route + trek path if available
    final polylines = <Polyline>{};

    // Driving route from user to destination (blue dashed style)
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('driving_route'),
        points: _routePoints,
        color: const Color(0xFF1A73E8), // Google Maps blue
        width: 5,
        patterns: [], // solid line
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ));
    }

    // Original trek path (green) — only for user-recorded routes
    for (final p in _buildPolylines()) {
      polylines.add(p);
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: zoom,
          ),
          polylines: polylines,
          markers: _buildMarkers(),
          mapType: MapType.normal,
          myLocationEnabled: _currentPosition != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            if (_routePoints.isNotEmpty) {
              // Already have route — fit to it
              final allPts = _currentPosition != null
                  ? [LatLng(_currentPosition!.latitude, _currentPosition!.longitude), ..._routePoints]
                  : _routePoints;
              Future.delayed(const Duration(milliseconds: 300), () {
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(_boundsFromLatLngs(allPts), 60),
                );
              });
            } else {
              final bounds = _getMapBounds();
              if (bounds != null) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 50),
                  );
                });
              }
            }
          },
        ),
        // Loading indicator while fetching route
        if (_isLoadingRoute)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: const Color(0xFF1A73E8)),
                  ),
                  const SizedBox(width: 6),
                  const Text('Loading route...', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildElevationChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spots = widget.trek.elevationProfile
        .map((p) => FlSpot(p.distance / 1000, p.elevation))
        .toList();

    if (spots.isEmpty) {
      return const SizedBox(height: 150, child: Center(child: Text('No elevation data')));
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 100,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.black12,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (widget.trek.distance / 1000) / 4,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toStringAsFixed(1)} km',
                    style: GoogleFonts.manrope(fontSize: 10),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: 200,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()} m',
                  style: GoogleFonts.manrope(fontSize: 10),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => isDark ? Colors.grey[800]! : Colors.white,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toInt()} m\n${spot.x.toStringAsFixed(1)} km',
                    GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No reviews yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Be the first to review this trek!',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _reviews.take(3).map((review) => _ReviewCard(review: review)).toList(),
    );
  }

  Widget _buildStartButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _startPath,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Path'),
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
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final TrekDifficulty difficulty;

  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        difficulty.displayName,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (difficulty) {
      case TrekDifficulty.easy:
        return AppColors.success;
      case TrekDifficulty.moderate:
        return AppColors.warning;
      case TrekDifficulty.difficult:
        return Colors.orange;
      case TrekDifficulty.expert:
        return AppColors.error;
    }
  }
}

class _ElevationStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ElevationStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final TrekReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: review.userAvatarUrl != null
                    ? CachedNetworkImageProvider(review.userAvatarUrl!)
                    : null,
                child: review.userAvatarUrl == null
                    ? Text(review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    RatingStars(rating: review.rating, size: 14),
                  ],
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              review.comment!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: CachedNetworkImage(
                      imageUrl: review.photoUrls[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return '${(diff.inDays / 30).floor()} months ago';
    }
  }
}

/// Dialog for adding a review
class _AddReviewDialog extends StatefulWidget {
  @override
  State<_AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<_AddReviewDialog> {
  double _rating = 5.0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rating', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1.0),
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Comment (optional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'rating': _rating,
              'comment': _commentController.text.isNotEmpty 
                  ? _commentController.text 
                  : null,
            });
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Fullscreen map with route from user location to destination
class _FullscreenMapScreen extends StatefulWidget {
  final Trek trek;
  final Position? currentPosition;

  const _FullscreenMapScreen({
    required this.trek,
    this.currentPosition,
  });

  @override
  State<_FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<_FullscreenMapScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

  static const String _mapsApiKey = 'AIzaSyA59STvjWZcL-k_gipSGBDV6u797zF0Q9M';

  @override
  void initState() {
    super.initState();
    if (widget.currentPosition != null && widget.trek.startPoint != null) {
      _fetchDirections();
    }
  }

  Future<void> _fetchDirections() async {
    final from = widget.currentPosition!;
    final dest = widget.trek.startPoint!;
    setState(() => _isLoadingRoute = true);

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${from.latitude},${from.longitude}'
      '&destination=${dest.latitude},${dest.longitude}'
      '&mode=driving'
      '&key=$_mapsApiKey',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final encoded = routes[0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encoded);
          if (mounted) {
            setState(() => _routePoints = points);
            Future.delayed(const Duration(milliseconds: 400), () {
              final allPts = [
                LatLng(from.latitude, from.longitude),
                ...points,
              ];
              _mapController?.animateCamera(
                CameraUpdate.newLatLngBounds(_boundsFromLatLngs(allPts), 60),
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Fullscreen directions error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += dLat;
      result = 0; shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += dLng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngs(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    // Driving route from user to destination
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('driving_route'),
        points: _routePoints,
        color: const Color(0xFF1A73E8),
        width: 5,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ));
    }

    // Trek route — only for user-recorded GPX/drawn paths
    if (widget.trek.routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('trek_route'),
        points: widget.trek.routePoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList(),
        color: AppColors.primary,
        width: 5,
      ));
    }

    return polylines;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final isGooglePlace = widget.trek.routePoints.isEmpty &&
        widget.trek.startPoint != null;

    // User location
    if (widget.currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    if (isGooglePlace) {
      // Single location pin for Google Places — start and end are the same
      markers.add(Marker(
        markerId: const MarkerId('place'),
        position: LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.trek.title),
      ));
      return markers;
    }

    // Start point
    if (widget.trek.startPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Start: ${widget.trek.title}'),
      ));
    }

    // End point
    if (widget.trek.endPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(widget.trek.endPoint!.latitude, widget.trek.endPoint!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'End Point'),
      ));
    }

    return markers;
  }

  LatLngBounds _getBounds() {
    final points = <LatLng>[];
    if (widget.currentPosition != null) {
      points.add(LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude));
    }
    // Prefer actual driving route points for tightest bounds
    if (_routePoints.isNotEmpty) {
      points.addAll(_routePoints);
    } else {
      if (widget.trek.startPoint != null) {
        points.add(LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude));
      }
      if (widget.trek.endPoint != null) {
        points.add(LatLng(widget.trek.endPoint!.latitude, widget.trek.endPoint!.longitude));
      }
      for (final p in widget.trek.routePoints) {
        points.add(LatLng(p.latitude, p.longitude));
      }
    }
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(12.9, 77.5),
        northeast: const LatLng(13.1, 77.7),
      );
    }
    return _boundsFromLatLngs(points);
  }

  @override
  Widget build(BuildContext context) {
    final isGooglePlace = widget.trek.routePoints.isEmpty &&
        widget.trek.startPoint != null;

    final initialPos = widget.trek.startPoint != null
        ? LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude)
        : widget.currentPosition != null
            ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
            : const LatLng(12.9716, 77.5946);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trek.title),
        actions: [
          if (isGooglePlace && widget.trek.startPoint != null)
            IconButton(
              icon: const Icon(Icons.directions),
              tooltip: 'Get Directions',
              onPressed: () async {
                final lat = widget.trek.startPoint!.latitude;
                final lng = widget.trek.startPoint!.longitude;
                final gmmIntent =
                    Uri.parse('google.navigation:q=$lat,$lng&mode=d');
                final gmmBrowser = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                if (await canLaunchUrl(gmmIntent)) {
                  await launchUrl(gmmIntent);
                } else {
                  await launchUrl(gmmBrowser,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          IconButton(
            icon: Icon(_mapType == MapType.normal ? Icons.satellite_alt : Icons.map),
            tooltip: 'Toggle map type',
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPos,
              zoom: isGooglePlace ? 14.5 : 13.0,
            ),
            mapType: _mapType,
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), () {
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(_getBounds(), 60),
                );
              });
            },
          ),
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendItem(color: const Color(0xFF1A73E8), label: 'Driving Route'),
                  if (!isGooglePlace) ...[
                    const SizedBox(height: 4),
                    _LegendItem(color: AppColors.primary, label: 'Trek Path'),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.blue[300], size: 16),
                      const SizedBox(width: 4),
                      const Text('You', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(isGooglePlace ? 'Place' : 'Start',
                          style: const TextStyle(fontSize: 12)),
                      if (!isGooglePlace) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        const Text('End', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Route loading indicator
          if (_isLoadingRoute)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Finding best route...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
