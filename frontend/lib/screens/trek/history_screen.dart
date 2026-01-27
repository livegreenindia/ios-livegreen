import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/trek.dart';
import '../../services/trek_service.dart';

/// Screen to display user's recorded track history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TrekService _trekService = TrekService();
  List<RecordedTrack> _tracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in to view history';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tracks = await _trekService.getUserTracks(limit: 50);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTrack(RecordedTrack track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Track?'),
        content: Text('Are you sure you want to delete "${track.title ?? 'Untitled track'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _trekService.deleteRecordedTrack(track.id);
        _loadTracks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Track deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _viewTrackDetails(RecordedTrack track) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TrackDetailsScreen(track: track),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'My History',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error!.contains('sign in'))
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                )
              else
                FilledButton.icon(
                  onPressed: _loadTracks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.route_outlined,
                size: 80,
                color: AppColors.primary.withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No tracks recorded',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Start a path and record your journey!\nYour tracks will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.explore),
                label: const Text('Start Exploring'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTracks,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _tracks.length,
        itemBuilder: (context, index) {
          final track = _tracks[index];
          return _TrackCard(
            track: track,
            onTap: () => _viewTrackDetails(track),
            onDelete: () => _deleteTrack(track),
          );
        },
      ),
    );
  }
}

/// Card widget for displaying a recorded track
class _TrackCard extends StatelessWidget {
  final RecordedTrack track;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TrackCard({
    required this.track,
    required this.onTap,
    required this.onDelete,
  });

  void _shareTrack() {
    final duration = track.endTime.difference(track.startTime);
    final avgSpeed = duration.inSeconds > 0
        ? (track.distance / 1000) / (duration.inSeconds / 3600)
        : 0;
    
    Share.share(
      '🏃 Trek Completed! 🏃\n\n'
      '📍 ${track.title ?? "My Trek"}\n\n'
      '📏 Distance: ${_formatDistance(track.distance)}\n'
      '⏱️ Duration: ${track.formattedDuration}\n'
      '⚡ Avg Speed: ${avgSpeed.toStringAsFixed(2)} km/h\n'
      '🔥 Calories: ${_safeToInt(track.caloriesBurned)} kcal\n'
      '📅 Date: ${_formatDate(track.startTime)}\n'
      '${track.notes != null && track.notes!.isNotEmpty ? "\n📝 Notes: ${track.notes}\n" : ""}'
      '\nDownload LiveGreen to track your treks!\n'
      'https://play.google.com/store/apps/details?id=com.livegreen.app',
      subject: track.title ?? 'My Trek',
    );
  }

  /// Build Google Maps preview showing the recorded route as a polyline
  Widget _buildMapPreview() {
    if (track.points.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Text('No route data'),
        ),
      );
    }

    final startPoint = track.points.first;
    final polylinePoints = track.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(startPoint.latitude, startPoint.longitude),
        zoom: 13,
      ),
      polylines: {
        Polyline(
          polylineId: const PolylineId('track_preview'),
          points: polylinePoints,
          color: AppColors.primary,
          width: 4,
          geodesic: true,
        ),
      },
      markers: {
        // Green marker at start
        Marker(
          markerId: const MarkerId('start'),
          position: polylinePoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'Start',
            snippet: 'Starting point',
          ),
        ),
        // Red marker at end
        if (polylinePoints.length > 1)
          Marker(
            markerId: const MarkerId('end'),
            position: polylinePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(
              title: 'End',
              snippet: 'Ending point',
            ),
          ),
      },
      mapType: MapType.terrain,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.route,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title ?? 'Untitled Track',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(track.startTime),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    color: colorScheme.primary,
                    onPressed: _shareTrack,
                    tooltip: 'Share',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              // Map preview with polyline route (Google Maps style)
              if (track.points.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    height: 160,
                    child: _buildMapPreview(),
                  ),
                )
              else
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                    child: Text('No route data'),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: _formatDistance(track.distance),
                  ),
                  _StatItem(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: track.formattedDuration,
                  ),
                  _StatItem(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Calories',
                    value: '${_safeToInt(track.caloriesBurned)} kcal',
                  ),
                ],
              ),
              if (track.notes != null && track.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  track.notes!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDistance(double meters) {
    // Handle invalid values (NaN, Infinity)
    if (!meters.isFinite || meters < 0) {
      return '0 m';
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }

  /// Safe integer conversion that handles NaN and Infinity
  int _safeToInt(double value) {
    if (!value.isFinite || value.isNaN) {
      return 0;
    }
    return value.toInt();
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
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Detailed view of a recorded track
class _TrackDetailsScreen extends StatefulWidget {
  final RecordedTrack track;

  const _TrackDetailsScreen({required this.track});

  @override
  State<_TrackDetailsScreen> createState() => _TrackDetailsScreenState();
}

class _TrackDetailsScreenState extends State<_TrackDetailsScreen> {
  late MapType _mapType;

  @override
  void initState() {
    super.initState();
    _mapType = MapType.terrain;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.track.title ?? 'Track Details',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        actions: [
          // Map type selector
          PopupMenuButton<MapType>(
            onSelected: (MapType result) {
              setState(() => _mapType = result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
              const PopupMenuItem<MapType>(
                value: MapType.normal,
                child: Row(
                  children: [
                    Icon(Icons.map, size: 20),
                    SizedBox(width: 8),
                    Text('Normal'),
                  ],
                ),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.terrain,
                child: Row(
                  children: [
                    Icon(Icons.landscape, size: 20),
                    SizedBox(width: 8),
                    Text('Terrain'),
                  ],
                ),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.satellite,
                child: Row(
                  children: [
                    Icon(Icons.satellite, size: 20),
                    SizedBox(width: 8),
                    Text('Satellite'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-size map with enhanced styling (like Google Maps)
            SizedBox(
              height: 400,
              child: _buildDetailedMap(),
            ),
            
            // Stats
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistics',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatsGrid(),
                  
                  if (widget.track.notes != null && widget.track.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Notes',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.track.notes!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build detailed Google Maps view with styled polyline (Google Maps style)
  Widget _buildDetailedMap() {
    if (widget.track.points.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Text('No route data available'),
        ),
      );
    }

    final startPoint = widget.track.points.first;
    final polylinePoints = widget.track.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(startPoint.latitude, startPoint.longitude),
            zoom: 14,
          ),
          polylines: {
            // Main route polyline (bold, visible blue)
            Polyline(
              polylineId: const PolylineId('track_main'),
              points: polylinePoints,
              color: const Color(0xFF2196F3), // Bright blue
              width: 8,
              geodesic: true,
            ),
          },
          markers: {
            // Green marker at start
            Marker(
              markerId: const MarkerId('start'),
              position: polylinePoints.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: '🟢 Start Point',
                snippet: '${polylinePoints.first.latitude.toStringAsFixed(4)}, ${polylinePoints.first.longitude.toStringAsFixed(4)}',
              ),
            ),
            // Red marker at end
            if (polylinePoints.length > 1)
              Marker(
                markerId: const MarkerId('end'),
                position: polylinePoints.last,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: '🔴 End Point',
                  snippet: '${polylinePoints.last.latitude.toStringAsFixed(4)}, ${polylinePoints.last.longitude.toStringAsFixed(4)}',
                ),
              ),
          },
          mapType: _mapType,
          myLocationEnabled: false,
          zoomControlsEnabled: true,
        ),
        // Legend overlay (Google Maps style)
        Positioned(
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Start',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'End',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Route',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      children: [
        _StatTile(
          icon: Icons.straighten,
          label: 'Distance',
          value: _formatDistance(widget.track.distance),
          color: AppColors.primary,
        ),
        _StatTile(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: widget.track.formattedDuration,
          color: AppColors.info,
        ),
        _StatTile(
          icon: Icons.speed,
          label: 'Avg Speed',
          value: '${(widget.track.avgSpeed * 3.6).toStringAsFixed(1)} km/h',
          color: AppColors.warning,
        ),
        _StatTile(
          icon: Icons.bolt,
          label: 'Max Speed',
          value: '${(widget.track.maxSpeed * 3.6).toStringAsFixed(1)} km/h',
          color: AppColors.error,
        ),
        _StatTile(
          icon: Icons.trending_up,
          label: 'Elevation Gain',
          value: '+${_safeToInt(widget.track.elevationGain)} m',
          color: AppColors.success,
        ),
        _StatTile(
          icon: Icons.local_fire_department,
          label: 'Calories',
          value: '${_safeToInt(widget.track.caloriesBurned)} kcal',
          color: Colors.orange,
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    // Handle invalid values (NaN, Infinity)
    if (!meters.isFinite || meters < 0) {
      return '0 m';
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }

  /// Safe integer conversion that handles NaN and Infinity
  int _safeToInt(double value) {
    if (!value.isFinite || value.isNaN) {
      return 0;
    }
    return value.toInt();
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
