import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../models/trek.dart';

/// Premium trek card widget with Material 3 styling
class TrekCard extends StatelessWidget {
  final Trek trek;
  final VoidCallback? onTap;
  final VoidCallback? onViewDetails;
  final bool showUsersBadge;
  final double? distance; // Distance from user in km

  const TrekCard({
    super.key,
    required this.trek,
    this.onTap,
    this.onViewDetails,
    this.showUsersBadge = true,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image with gradient overlay
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: trek.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: trek.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildImagePlaceholder(isDark),
                          errorWidget: (context, url, error) => _buildImageFallback(isDark),
                        )
                      : _buildImageFallback(isDark),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
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
                ),
                // Difficulty badge
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Row(
                    children: [
                      _DifficultyBadge(difficulty: trek.difficulty),
                      // OSM discovered badge
                      if (trek.id.startsWith('osm_')) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.explore, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Discovered',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Users today badge
                if (showUsersBadge && trek.usersToday > 0)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _UsersBadge(count: trek.usersToday),
                  ),
                // Distance from user badge
                if (distance != null)
                  Positioned(
                    top: AppSpacing.sm,
                    right: showUsersBadge && trek.usersToday > 0 
                        ? AppSpacing.sm + 70 // Offset if users badge is shown
                        : AppSpacing.sm,
                    child: _DistanceBadge(distanceKm: distance!),
                  ),
                // Title on image
                Positioned(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Text(
                    trek.title,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.straighten,
                        label: trek.formattedDistance,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatChip(
                        icon: Icons.schedule,
                        label: trek.formattedTime,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatChip(
                        icon: Icons.trending_up,
                        label: trek.formattedElevationGain,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Description
                  Text(
                    trek.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // View details button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: onViewDetails ?? onTap,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('VIEW DETAILS'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildImageFallback(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.terrain,
          size: 48,
          color: isDark ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
    );
  }
}

/// Difficulty badge widget
class _DifficultyBadge extends StatelessWidget {
  final TrekDifficulty difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        difficulty.displayName,
        style: GoogleFonts.manrope(
          fontSize: 11,
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

/// Users today badge
class _UsersBadge extends StatelessWidget {
  final int count;

  const _UsersBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$count today',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Distance from user badge
class _DistanceBadge extends StatelessWidget {
  final double distanceKm;

  const _DistanceBadge({required this.distanceKm});

  String get _formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.toInt()} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.near_me,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _formattedDistance,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat chip widget
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

/// Filter chip for trek categories
class TrekFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const TrekFilterChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      avatar: icon != null
          ? Icon(
              icon,
              size: 18,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            )
          : null,
      selected: selected,
      onSelected: (_) => onTap?.call(),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: GoogleFonts.manrope(
        fontWeight: FontWeight.w500,
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

/// Loading shimmer for trek list
class TrekCardShimmer extends StatelessWidget {
  const TrekCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Container(height: 24, width: 60, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Container(height: 24, width: 60, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Container(height: 24, width: 60, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(height: 12, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(height: 12, width: 200, color: Colors.white),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 40,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for trek list
class TrekEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRetry;

  const TrekEmptyState({
    super.key,
    this.title = 'No treks found',
    this.subtitle = 'Try adjusting your filters or check back later',
    this.icon = Icons.terrain_outlined,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Speed dial FAB for trek actions
class TrekSpeedDialFAB extends StatefulWidget {
  final VoidCallback? onImportGPX;
  final VoidCallback? onRecordTrack;
  final VoidCallback? onDrawPath;

  const TrekSpeedDialFAB({
    super.key,
    this.onImportGPX,
    this.onRecordTrack,
    this.onDrawPath,
  });

  @override
  State<TrekSpeedDialFAB> createState() => _TrekSpeedDialFABState();
}

class _TrekSpeedDialFABState extends State<TrekSpeedDialFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speed dial options
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isOpen
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SpeedDialOption(
                      label: 'Import GPX',
                      icon: Icons.upload_file,
                      onTap: () {
                        _toggle();
                        widget.onImportGPX?.call();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SpeedDialOption(
                      label: 'Record Track',
                      icon: Icons.fiber_manual_record,
                      color: AppColors.error,
                      onTap: () {
                        _toggle();
                        widget.onRecordTrack?.call();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SpeedDialOption(
                      label: 'Draw Path',
                      icon: Icons.edit_road,
                      onTap: () {
                        _toggle();
                        widget.onDrawPath?.call();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _SpeedDialOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _SpeedDialOption({
    required this.label,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: effectiveColor,
          foregroundColor: Colors.white,
          child: Icon(icon),
        ),
      ],
    );
  }
}

/// Stat card for trek overview
class TrekStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const TrekStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, color: effectiveColor, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating stars widget
class RatingStars extends StatelessWidget {
  final double rating;
  final int maxStars;
  final double size;
  final Color? color;

  const RatingStars({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        final starValue = index + 1;
        IconData iconData;
        
        if (rating >= starValue) {
          iconData = Icons.star;
        } else if (rating >= starValue - 0.5) {
          iconData = Icons.star_half;
        } else {
          iconData = Icons.star_border;
        }
        
        return Icon(iconData, size: size, color: starColor);
      }),
    );
  }
}
