import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // Stored for potential future camera animations
  // ignore: unused_field
  GoogleMapController? _mapController;
  bool _isFavorite = false;
  List<TrekReview> _reviews = [];
  bool _isLoadingReviews = true;
  Position? _currentPosition;

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
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
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
    if (widget.trek.routePoints.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.trek.routePoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList(),
        color: AppColors.primary,
        width: 4,
        patterns: [PatternItem.dot, PatternItem.gap(10)],
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.trek.startPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(
          widget.trek.startPoint!.latitude,
          widget.trek.startPoint!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
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
        infoWindow: const InfoWindow(title: 'End'),
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
                  // TODO: Implement share
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
                            'Route Map',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: _openFullscreenMap,
                            icon: const Icon(Icons.fullscreen, size: 18),
                            label: const Text('Fullscreen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: SizedBox(
                          height: 250,
                          child: _buildMap(),
                        ),
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
    final initialPosition = widget.trek.startPoint != null
        ? LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude)
        : const LatLng(20.5937, 78.9629); // Default to India center

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 12,
      ),
      polylines: _buildPolylines(),
      markers: _buildMarkers(),
      mapType: MapType.terrain,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
        // Fit bounds after map is created
        final bounds = _getMapBounds();
        if (bounds != null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          });
        }
      },
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
  // ignore: unused_field
  GoogleMapController? _mapController;
  MapType _mapType = MapType.terrain;

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    // Trek route
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

    // Route from user to start point
    if (widget.currentPosition != null && widget.trek.startPoint != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('user_to_start'),
        points: [
          LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
          LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude),
        ],
        color: Colors.blue,
        width: 4,
        patterns: [PatternItem.dash(15), PatternItem.gap(10)],
      ));
    }

    return polylines;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // User location
    if (widget.currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
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
    if (widget.trek.startPoint != null) {
      points.add(LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude));
    }
    if (widget.trek.endPoint != null) {
      points.add(LatLng(widget.trek.endPoint!.latitude, widget.trek.endPoint!.longitude));
    }
    for (final p in widget.trek.routePoints) {
      points.add(LatLng(p.latitude, p.longitude));
    }

    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(12.9, 77.5),
        northeast: const LatLng(13.1, 77.7),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
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

  @override
  Widget build(BuildContext context) {
    final initialPos = widget.trek.startPoint != null
        ? LatLng(widget.trek.startPoint!.latitude, widget.trek.startPoint!.longitude)
        : widget.currentPosition != null
            ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
            : const LatLng(12.9716, 77.5946);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trek.title),
        actions: [
          IconButton(
            icon: Icon(_mapType == MapType.terrain ? Icons.satellite : Icons.terrain),
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.terrain ? MapType.satellite : MapType.terrain;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 13),
            mapType: _mapType,
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
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
                  _LegendItem(color: Colors.blue, label: 'Route to Start', isDashed: true),
                  const SizedBox(height: 4),
                  _LegendItem(color: AppColors.primary, label: 'Trek Path'),
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
                      const Text('Start', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      const Text('End', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
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
