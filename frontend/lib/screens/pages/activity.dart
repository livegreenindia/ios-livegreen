import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api.dart';
import '../../services/completion_store.dart';
import '../../services/local_cache.dart';
import '../../services/wellness_activity_service.dart';
import '../../services/progress_calculator_service.dart';
import '../../config/api.dart' as cfg;
import '../../theme/app_theme.dart';
import 'progress_refresh_notifier.dart';
import 'package:provider/provider.dart';
import '../../models/lux.dart';
import 'meditation.dart';
import '../../models/deepWork.dart';
import '../../models/screen_control.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int _happiness = 5;
  List<Map<String, dynamic>> _activities = [];
  final Map<String, bool> _completedCache = {};
  bool _happinessSubmitting = false;
  bool _activitiesLoading = false;
  String? _activitiesError;
  String? _wellnessProfile;
  String? _selectedTimeSlot; // Currently selected time slot filter

  // Wellness rate limiting state
  int? _lastWellnessScore;
  DateTime? _lastWellnessTime;
  bool _wellnessLoading = true;

  // Progress tracking
  int _completedCount = 0;
  int _expectedCount = 0;
  int _completionPercent = 0;
  StreamSubscription<Map<String, dynamic>>? _progressSub;

  // MBSR Timer state management
  final Map<String, bool> _timerRunning = {};
  final Map<String, int> _timerSeconds = {};
  final Map<String, Timer?> _activeTimers = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  // MBSR Breathing exercise state
  final Map<String, String> _breathingRatio = {};
  final Map<String, bool> _breathingPaused = {};
  final Map<String, int> _breathingCycles = {};
  final Map<String, String> _breathingPhase = {};
  final Map<String, int> _totalDurationSeconds = {};
  final Map<String, int> _elapsedSeconds = {};
  final Map<String, String> _breathingType = {};
  final AudioPlayer _breathingAudioPlayer = AudioPlayer();
  final AudioPlayer _phaseAudioPlayer = AudioPlayer();

  // Theme-aware color getters
  Color get primaryColor => AppColors.primary;
  Color get backgroundLight => AppColors.backgroundLight;
  Color get backgroundDark => AppColors.backgroundDark;

  Widget activityCard(Map<String, dynamic> activity) {
    final title = activity['title'] ?? activity['id'] ?? 'Activity';
    final subtitle = activity['subtitle'] ?? activity['description'] ?? '';
    final iconName = activity['icon'] as String?;
    IconData icon = Icons.nature_people;
    if (iconName != null) {
      switch (iconName) {
        case 'favorite':
          icon = Icons.favorite;
          break;
        case 'fitness_center':
          icon = Icons.fitness_center;
          break;
        case 'restaurant':
          icon = Icons.restaurant;
          break;
        case 'self_improvement':
          icon = Icons.self_improvement;
          break;
        case 'work':
          icon = Icons.work;
          break;
        case 'people':
          icon = Icons.people;
          break;
        case 'spa':
          icon = Icons.spa;
          break;
        case 'bedtime':
          icon = Icons.bedtime;
          break;
        case 'school':
          icon = Icons.school;
          break;
        case 'palette':
          icon = Icons.palette;
          break;
        case 'psychology':
          icon = Icons.psychology;
          break;
        case 'park':
          icon = Icons.park;
          break;
        case 'shower':
          icon = Icons.shower;
          break;
        case 'grass':
          icon = Icons.grass;
          break;
        case 'travel_explore':
          icon = Icons.travel_explore;
          break;
        case 'lightbulb':
          icon = Icons.lightbulb_outline;
          break;
        case 'directions_bike':
          icon = Icons.directions_bike;
          break;
        case 'shopping_bag':
          icon = Icons.shopping_bag_outlined;
          break;
        case 'water_drop':
          icon = Icons.water_drop_outlined;
          break;
        default:
          icon = Icons.nature_people;
      }
    }

    final activityId =
        activity['id'] ?? title.toLowerCase().replaceAll(' ', '_');
    final completed = _completedCache[activityId] ?? false;

    Widget actionButton;
    if (completed) {
      actionButton = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 6),
            Text(
              "Done",
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    } else {
      actionButton = ElevatedButton(
        onPressed: () async {
          final api = ApiService(baseUrl: cfg.apiBaseUrl);
          final messengerBefore = ScaffoldMessenger.maybeOf(context);
          final notifierBefore = Provider.of<ProgressRefreshNotifier>(
            context,
            listen: false,
          );

          // Show immediate feedback
          setState(() {
            _completedCache[activityId] = true;
          });

          try {
            final now = DateTime.now();
            final localDate =
                '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            // Debug log for troubleshooting
            debugPrint(
              '[Activity] Completing activity: $activityId on $localDate',
            );

            await api.completeActivity(activityId, {
              'date': now.toIso8601String(),
              'localDate': localDate,
              'weight':
                  activity['weight'] ?? 10, // Wellness activities use weight 10
              'isWellnessActivity': activity['isWellnessActivity'] ?? false,
            }).timeout(const Duration(seconds: 15));

            await CompletionStore.markCompleted(activityId);
            RecentDataStore.recordActivityComplete(100, DateTime.now());

            if (!mounted) return;

            // Show completion dialog with share option
            _showCompletionDialog(activity);

            notifierBefore.triggerRefresh();
          } catch (e) {
            final errorStr = e.toString();
            debugPrint('[Activity] Error completing activity: $errorStr');

            // Check if it's "already_completed" - this is actually success (edge case from prior completion)
            if (errorStr.contains('already_completed') ||
                errorStr.contains('409')) {
              // Activity was already completed, just mark as done locally
              await CompletionStore.markCompleted(activityId);
              if (!mounted) return;
              messengerBefore?.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('Activity already completed today!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }

            // Revert optimistic update on actual error
            if (mounted) {
              setState(() {
                _completedCache[activityId] = false;
              });
            }

            String userMessage = 'Could not complete activity';
            if (errorStr.contains('TimeoutException')) {
              userMessage =
                  'Request timed out. Please check your internet connection';
            } else if (errorStr.contains('SocketException')) {
              userMessage = 'No internet connection. Please try again';
            } else if (errorStr.contains('FormatException')) {
              userMessage = 'Server error. Please try again later';
            } else if (errorStr.contains('401') ||
                errorStr.contains('Unauthorized')) {
              userMessage = 'Session expired. Please sign in again';
            } else if (errorStr.contains('500')) {
              userMessage = 'Server error. Please try again later';
            }

            if (!mounted) return;
            messengerBefore?.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(userMessage)),
                  ],
                ),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    // User can pull down to refresh or tap the activity complete button again
                    _loadActivities();
                  },
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Complete",
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, size: 14),
          ],
        ),
      );
    }

    final category = activity['category'] as String?;
    final categoryColor = _getCategoryColor(category);

    return Card(
      elevation: completed ? 1 : 3,
      shadowColor: completed ? Colors.transparent : categoryColor.withAlpha(40),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: completed
              ? LinearGradient(
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade50.withAlpha(100),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: Border.all(
            color: completed ? Colors.green.shade200 : Colors.transparent,
            width: completed ? 1.5 : 0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with nature-inspired design
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: completed
                          ? [Colors.green.shade100, Colors.green.shade50]
                          : [
                              categoryColor.withAlpha(40),
                              categoryColor.withAlpha(20),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: completed
                        ? null
                        : [
                            BoxShadow(
                              color: categoryColor.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          icon,
                          color:
                              completed ? Colors.green.shade700 : categoryColor,
                          size: 28,
                        ),
                      ),
                      if (completed)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                height: 1.3,
                                letterSpacing: -0.2,
                                decoration: completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.green.shade400,
                                color: completed ? Colors.grey.shade600 : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Show clock icon for mindfulness/MBSR activities, info icon for others with details
                          if (activity['isWellnessActivity'] == true &&
                              (activity['description'] != null ||
                                  activity['tips'] != null ||
                                  activity['youtubeUrl'] != null))
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showActivityInfo(context, activity),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _isMindfulnessActivity(activity) ||
                                          _isScreenControlActivity(activity)
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isMindfulnessActivity(activity) ||
                                            _isScreenControlActivity(activity)
                                        ? const Color(0xFFD7CCC8)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isMindfulnessActivity(activity) ||
                                              _isScreenControlActivity(activity)
                                          ? Icons.play_arrow_rounded
                                          : Icons.info_outline,
                                      color: _isMindfulnessActivity(activity) ||
                                              _isScreenControlActivity(activity)
                                          ? const Color(0xFF800000)
                                          : primaryColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isMindfulnessActivity(activity) ||
                                              _isScreenControlActivity(activity)
                                          ? 'Practice'
                                          : 'Details',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            _isMindfulnessActivity(activity) ||
                                                    _isScreenControlActivity(
                                                        activity)
                                                ? const Color(0xFF800000)
                                                : primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Spacer(),
                          // action button (cached) inserted here
                          actionButton,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show detailed activity information in a modal bottom sheet
  void _showActivityInfo(BuildContext context, Map<String, dynamic> activity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = activity['title'] ?? 'Activity';
    final description = activity['description'];
    final tips = activity['tips'] as List<dynamic>?;
    final youtubeUrl = activity['youtubeUrl'] as String?;
    final category = activity['category'] as String?;
    final activityId = activity['id']?.toString() ?? 'mbsr_activity';

    // Check if this is a meditation activity - navigate to meditation screen
    if (title.toLowerCase().contains('meditation') &&
        !title.toLowerCase().contains('breathing')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MeditationScreen()),
      );
      return;
    }

    // Check if this is a deep work/study activity - navigate to deep work screen
    if (_isDeepWorkActivity(activity)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeepWorkScreen()),
      );
      return;
    }

    // Screen control/digital wellness activities open the screen control flow
    if (_isScreenControlActivity(activity)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PermissionWrapper()),
      );
      return;
    }

    // Check if this is a mindfulness/MBSR activity - show breathing dialog instead
    if (category?.toLowerCase() == 'mindfulness' ||
        title.toLowerCase().contains('mbsr') ||
        title.toLowerCase().contains('mindfulness') ||
        title.toLowerCase().contains('breathing')) {
      _showMBSRBreathingDialog(activityId, title);
      return;
    }

    // If activity relates to light measurement, open the Lux Meter sheet
    if (_isLuxActivity(activity)) {
      _showLuxMeterSheet(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with category icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getCategoryIconData(activity['icon']),
                            color: _getCategoryColor(category),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Description
                    if (description != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Why This Matters',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],

                    // Tips
                    if (tips != null && tips.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Quick Tips',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...tips.map(
                        (tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(category),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tip.toString(),
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // YouTube button
                    if (youtubeUrl != null) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL(youtubeUrl),
                          icon: const Icon(Icons.play_circle_outline, size: 20),
                          label: Text(
                            'Learn More on YouTube',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get category color
  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'health':
        return const Color(0xFFE91E63);
      case 'fitness':
        return const Color(0xFF2196F3);
      case 'nutrition':
        return const Color(0xFFFF9800);
      case 'mindfulness':
        return const Color(0xFF9C27B0);
      case 'nature':
        return const Color(0xFF4CAF50);
      case 'productivity':
        return const Color(0xFF607D8B);
      case 'social':
        return const Color(0xFFFF5722);
      case 'relaxation':
        return const Color(0xFF00BCD4);
      default:
        return primaryColor;
    }
  }

  /// Get IconData from icon name
  IconData _getCategoryIconData(String? iconName) {
    switch (iconName) {
      case 'favorite':
        return Icons.favorite;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'restaurant':
        return Icons.restaurant;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'work':
        return Icons.work;
      case 'people':
        return Icons.people;
      case 'spa':
        return Icons.spa;
      case 'park':
        return Icons.park;
      case 'bedtime':
        return Icons.bedtime;
      case 'book':
        return Icons.book;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      default:
        return Icons.nature_people;
    }
  }

  /// Build time slot tabs for filtering
  Widget _buildTimeSlotTabs() {
    if (_activities.isEmpty) return const SizedBox.shrink();

    // Get all unique time slots from activities
    final timeSlots = <String>{};
    for (final activity in _activities) {
      final timeSlot = activity['timeSlot'] as String?;
      if (timeSlot != null && timeSlot.isNotEmpty) {
        timeSlots.add(timeSlot);
      }
    }

    if (timeSlots.isEmpty) return const SizedBox.shrink();

    // Sort time slots by order
    final sortedTimeSlots = timeSlots.toList()
      ..sort((a, b) {
        final aActivity = _activities.firstWhere((act) => act['timeSlot'] == a);
        final bActivity = _activities.firstWhere((act) => act['timeSlot'] == b);
        final aOrder = aActivity['timeSlotOrder'] as int? ?? 999;
        final bOrder = bActivity['timeSlotOrder'] as int? ?? 999;
        return aOrder.compareTo(bOrder);
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sortedTimeSlots.map((timeSlot) {
            final isSelected = _selectedTimeSlot == timeSlot;
            final currentTimeSlot =
                WellnessActivityService.getCurrentTimeSlot();
            final isCurrent = timeSlot.toLowerCase().contains(
                  currentTimeSlot.toLowerCase(),
                );

            // Extract short name (e.g., "Morning" from "Morning (6am-9am)")
            final shortName = timeSlot.split('(').first.trim();

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedTimeSlot = timeSlot;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isCurrent
                              ? primaryColor.withOpacity(0.35)
                              : Colors.grey.shade300),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent && !isSelected) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        shortName,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isCurrent
                                  ? primaryColor
                                  : Colors.grey.shade700),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Launch URL
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadActivities,
          color: primaryColor,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Custom header matching progress screen style
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, const Color(0xFF43A047)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_activity,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Activities",
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          "Complete daily activities",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button moved to header
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: _activitiesLoading
                          ? Colors.grey
                          : (isDark ? Colors.white70 : Colors.black54),
                      size: 22,
                    ),
                    tooltip: 'Refresh Activities',
                    onPressed: _activitiesLoading ? null : _loadActivities,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Today's Progress Card
              _buildProgressCard(),
              const SizedBox(height: 16),

              // Happiness Tracker Card (Nature-themed)
              Card(
                elevation: 3,
                shadowColor: primaryColor.withAlpha(30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.sentiment_satisfied_alt,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Happiness Check",
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: primaryColor,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "How happy are you feeling today?",
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withAlpha(40),
                                  primaryColor.withAlpha(20),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withAlpha(50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _getHappinessEmoji(_happiness),
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$_happiness",
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Show last logged wellness info
                      if (_lastWellnessScore != null && !_canLogWellness) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last logged: ${_getHappinessEmoji(_lastWellnessScore!)} $_lastWellnessScore/10',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Next log available in $_hoursUntilNextLog hour${_hoursUntilNextLog == 1 ? '' : 's'}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Slider(
                        min: 1,
                        max: 10,
                        value: _happiness.toDouble(),
                        activeColor:
                            _canLogWellness ? primaryColor : Colors.grey,
                        inactiveColor: Colors.grey.shade200,
                        onChanged: _canLogWellness
                            ? (value) {
                                setState(() {
                                  _happiness = value.toInt();
                                });
                              }
                            : null,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "😢 Unhappy",
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "😊 Very Happy",
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: (_happinessSubmitting ||
                                    !_canLogWellness ||
                                    _wellnessLoading)
                                ? null
                                : () async {
                                    setState(() {
                                      _happinessSubmitting = true;
                                    });
                                    final api = ApiService(
                                      baseUrl: cfg.apiBaseUrl,
                                    );
                                    final messengerBefore =
                                        ScaffoldMessenger.maybeOf(context);
                                    final notifierBefore =
                                        Provider.of<ProgressRefreshNotifier>(
                                      context,
                                      listen: false,
                                    );
                                    try {
                                      await api
                                          .postHappiness(_happiness)
                                          .timeout(const Duration(seconds: 10));
                                      if (!mounted) return;
                                      // Update local state after successful submission
                                      setState(() {
                                        _lastWellnessScore = _happiness;
                                        _lastWellnessTime = DateTime.now();
                                      });
                                      messengerBefore?.showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.favorite,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Thank you for sharing! Keep up the positivity 💚',
                                              ),
                                            ],
                                          ),
                                          backgroundColor: primaryColor,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      notifierBefore.triggerRefresh();
                                    } on WellnessRateLimitException catch (e) {
                                      // Handle rate limiting from server
                                      if (!mounted) return;
                                      setState(() {
                                        if (e.lastScore != null)
                                          _lastWellnessScore = e.lastScore;
                                        if (e.lastTimestamp != null) {
                                          _lastWellnessTime = DateTime.parse(
                                            e.lastTimestamp!,
                                          );
                                        }
                                      });
                                      messengerBefore?.showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(child: Text(e.message)),
                                            ],
                                          ),
                                          backgroundColor:
                                              Colors.amber.shade700,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    } catch (e) {
                                      String userMessage =
                                          'Could not save happiness level';
                                      if (e.toString().contains(
                                            'TimeoutException',
                                          )) {
                                        userMessage =
                                            'Request timed out. Please check your connection';
                                      } else if (e.toString().contains(
                                            'SocketException',
                                          )) {
                                        userMessage =
                                            'No internet. Your happiness level will be saved when you\'re back online';
                                      }

                                      if (!mounted) return;
                                      messengerBefore?.showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.warning_amber,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(userMessage),
                                              ),
                                            ],
                                          ),
                                          backgroundColor:
                                              Colors.orange.shade600,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _happinessSubmitting = false;
                                        });
                                      }
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _canLogWellness && !_wellnessLoading
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primaryLight,
                                          AppColors.primary,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade400,
                                          Colors.grey.shade500,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _canLogWellness && !_wellnessLoading
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withAlpha(60),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: (_happinessSubmitting ||
                                        _wellnessLoading)
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _canLogWellness
                                                ? Icons.sentiment_satisfied_alt
                                                : Icons.lock_clock,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _canLogWellness
                                                ? 'Submit Happiness'
                                                : 'Logged Today',
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time Slot Tabs
              _buildTimeSlotTabs(),

              // Activities Section Header with personalized greeting
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_wellnessProfile != null) ...[
                            // Personalized greeting
                            Text(
                              'Your Daily Activities',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Based on your $_wellnessProfile lifestyle',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ] else ...[
                            // Default header
                            Text(
                              'Daily Activities',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_activitiesLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),

              // Error State
              if (_activitiesError != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load activities',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _activitiesError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadActivities,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Empty State
              else if (_activities.isEmpty && !_activitiesLoading)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.eco,
                          size: 64,
                          color: primaryColor.withAlpha((0.5 * 255).round()),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No activities available',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new eco-friendly activities!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Activities List - Grouped by Time Slot
              else
                ..._buildGroupedActivities(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build activities grouped by time slot
  List<Widget> _buildGroupedActivities() {
    if (_activities.isEmpty) return [];

    // Check if activities have time slot information
    final hasTimeSlots = _activities.any((a) => a.containsKey('timeSlot'));

    if (!hasTimeSlots) {
      // No time slots - display as flat list (for non-wellness activities)
      return _activities.map((a) => activityCard(a)).toList();
    }

    // Filter activities by selected time slot
    final filteredActivities = _selectedTimeSlot != null
        ? _activities.where((a) => a['timeSlot'] == _selectedTimeSlot).toList()
        : _activities;

    if (filteredActivities.isEmpty) return [];

    final widgets = <Widget>[];

    // Get time slot info
    final timeSlot = _selectedTimeSlot ?? 'Activities';
    final currentTimeSlot = WellnessActivityService.getCurrentTimeSlot();
    final isCurrentSlot = timeSlot.toLowerCase().contains(
          currentTimeSlot.toLowerCase(),
        );
    final timeSlotDescription = _getTimeSlotDescription(timeSlot);

    // Time slot header with description
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCurrentSlot
                          ? [
                              primaryColor.withOpacity(0.18),
                              primaryColor.withOpacity(0.08),
                            ]
                          : [Colors.grey.shade100, Colors.grey.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isCurrentSlot ? primaryColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCurrentSlot
                            ? Icons.access_time_filled
                            : Icons.access_time,
                        size: 16,
                        color:
                            isCurrentSlot ? primaryColor : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeSlot,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrentSlot
                              ? primaryColor
                              : Colors.grey.shade700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (isCurrentSlot) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'NOW',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Time slot description
            if (timeSlotDescription != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  timeSlotDescription,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isCurrentSlot
                        ? primaryColor.withOpacity(0.85)
                        : Colors.grey.shade600,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Add all activities for selected time slot
    for (final activity in filteredActivities) {
      widgets.add(activityCard(activity));
    }

    return widgets;
  }

  /// Get description for time slot to show purpose
  String? _getTimeSlotDescription(String timeSlot) {
    final lowerSlot = timeSlot.toLowerCase();

    if (lowerSlot.contains('morning')) {
      return '🌅 Start your day with energy and intention';
    } else if (lowerSlot.contains('mid-day') || lowerSlot.contains('midday')) {
      return '☀️ Sustain productivity and well-being';
    } else if (lowerSlot.contains('afternoon')) {
      return '🌤️ Restore energy and creativity';
    } else if (lowerSlot.contains('evening')) {
      return '🌙 Prepare for restful sleep';
    } else if (lowerSlot.contains('weekend')) {
      return '🎉 Enjoy nature and recreation';
    }
    return null;
  }

  String _getHappinessEmoji(int level) {
    // Happiness-themed emojis
    if (level <= 2) return '😢'; // Very sad
    if (level <= 4) return '😕'; // Unhappy
    if (level <= 6) return '😐'; // Neutral
    if (level <= 8) return '😊'; // Happy
    return '😄'; // Very happy
  }

  /// Build the progress card showing today's activity completion
  Widget _buildProgressCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressPercent = _completionPercent / 100;

    // Get emoji based on progress
    String progressEmoji;
    String progressMessage;
    Color progressColor;

    if (_completionPercent >= 80) {
      progressEmoji = '�';
      progressMessage = 'Outstanding! You\'re crushing your goals!';
      progressColor = const Color(0xFF2E7D32);
    } else if (_completionPercent >= 60) {
      progressEmoji = '⭐';
      progressMessage = 'Great progress! Keep it up!';
      progressColor = const Color(0xFF43A047);
    } else if (_completionPercent >= 40) {
      progressEmoji = '📈';
      progressMessage = 'Making steady progress!';
      progressColor = primaryColor;
    } else if (_completionPercent >= 20) {
      progressEmoji = '👍';
      progressMessage = 'Every step counts!';
      progressColor = const Color(0xFF66BB6A);
    } else {
      progressEmoji = '🚀';
      progressMessage = 'Ready to start your journey!';
      progressColor = const Color(0xFF81C784);
    }

    return Card(
      elevation: 4,
      shadowColor: progressColor.withAlpha(60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              progressColor.withAlpha(30),
              progressColor.withAlpha(10),
              isDark ? Colors.grey.shade900 : Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.4, 1.0],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: progressColor.withAlpha(40), width: 1),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        progressColor.withAlpha(50),
                        progressColor.withAlpha(25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    progressEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: progressColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "TODAY'S PROGRESS",
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: progressColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_completedCount of $_expectedCount Activities',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [progressColor, progressColor.withAlpha(200)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_completionPercent%',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress bar with leaf decoration
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 12,
                    backgroundColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                if (progressPercent > 0.1)
                  Positioned(
                    left: (MediaQuery.of(context).size.width - 80) *
                            progressPercent -
                        8,
                    top: -2,
                    child: Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Motivational message
            Row(
              children: [
                Icon(Icons.tips_and_updates, size: 16, color: progressColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progressMessage,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEcoStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Check if activity is a mindfulness/MBSR activity (shows clock instead of details)
  bool _isMindfulnessActivity(Map<String, dynamic> activity) {
    final title = (activity['title'] ?? '').toString().toLowerCase();
    final category = (activity['category'] ?? '').toString().toLowerCase();
    return category == 'mindfulness' ||
        title.contains('mbsr') ||
        title.contains('mindfulness') ||
        title.contains('breathing') ||
        title.contains('meditation');
  }

  /// Check if activity is a screen control/digital wellness activity
  bool _isScreenControlActivity(Map<String, dynamic> activity) {
    final title = (activity['title'] ?? '').toString().toLowerCase();
    final description =
        (activity['description'] ?? '').toString().toLowerCase();
    final category = (activity['category'] ?? '').toString().toLowerCase();
    const keywords = [
      'screen',
      'social media',
      'whatsapp',
      'distractions',
      'digital',
      'phone usage',
      'scrolling',
      'reels',
      'shorts',
    ];
    return keywords.any((k) =>
        title.contains(k) || description.contains(k) || category.contains(k));
  }

  /// Check if activity is a deep work/study activity
  bool _isDeepWorkActivity(Map<String, dynamic> activity) {
    final title = (activity['title'] ?? '').toString().toLowerCase();
    final category = (activity['category'] ?? '').toString().toLowerCase();
    return title.contains('deep work') ||
        title.contains('deep study') ||
        title.contains('focus session') ||
        category == 'deep work' ||
        category == 'productivity';
  }

  /// Detect if the activity pertains to light intensity / lux measurement
  bool _isLuxActivity(Map<String, dynamic> activity) {
    final title = (activity['title'] ?? '').toString().toLowerCase();
    final description =
        (activity['description'] ?? '').toString().toLowerCase();
    const keywords = [
      'lux',
      'light intensity',
      'light meter',
      'illuminance',
      'lighting',
    ];
    return keywords.any((k) => title.contains(k) || description.contains(k));
  }

  /// Show Lux Meter in a modal bottom sheet and dismiss when measurement stops
  void _showLuxMeterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: LightMeterApp(
                    onStop: () {
                      // Close the sheet when user stops measurement
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show completion dialog with share option
  void _showCompletionDialog(Map<String, dynamic> activity) {
    final activityTitle = activity['title'] ?? 'Activity';
    final category = activity['category'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Well Done! 🎉',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You completed "$activityTitle"',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Share your achievement with friends!',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.manrope(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _shareActivityCompletion(activityTitle, category);
              },
              icon: const Icon(Icons.share, size: 18),
              label: Text(
                'Share',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Share activity completion to social media
  void _shareActivityCompletion(String activityTitle, String category) {
    final String shareText =
        '''� I just completed "$activityTitle" on LiveGreen! 

Taking small steps towards a healthier, happier lifestyle. 💚✨

Join me on LiveGreen and start your wellness journey today!

#LiveGreen #Wellness #HealthyLiving #PersonalGrowth''';

    Share.share(shareText, subject: 'I completed an activity on LiveGreen!');
  }

  // ============== MBSR BREATHING EXERCISE METHODS ==============

  /// Show MBSR Mindfulness Breathing Practice Dialog
  void _showMBSRBreathingDialog(String activityId, String activityTitle) {
    String selectedRatio = '4:4:4:4';
    String selectedType = 'box';
    int selectedDuration = 4;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isRunning = _timerRunning[activityId] ?? false;
            final bool isPaused = _breathingPaused[activityId] ?? false;
            final String currentPhase = _breathingPhase[activityId] ?? '';
            final int remainingTotal =
                (_totalDurationSeconds[activityId] ?? 0) -
                    (_elapsedSeconds[activityId] ?? 0);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color(0xFF0D1F14),
              title: Row(
                children: [
                  Icon(Icons.self_improvement, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MBSR Practice',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRunning) ...[
                      Text(
                        'Select Your MBSR Pattern',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Box Breathing card
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedType = 'box';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selectedType == 'box'
                                ? primaryColor
                                : const Color(0xFF1A3A2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selectedType == 'box'
                                  ? primaryColor
                                  : Colors.grey[700]!,
                              width: selectedType == 'box' ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.crop_square,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Box Breathing',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Equal inhale, hold, exhale, hold for calm focus.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              if (selectedType == 'box') ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Choose ratio',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _mbsrRatioButton(
                                        '4:4:4:4',
                                        selectedRatio,
                                        (val) {
                                          setDialogState(() {
                                            selectedRatio = val;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _mbsrRatioButton(
                                        '5:5:5:5',
                                        selectedRatio,
                                        (val) {
                                          setDialogState(() {
                                            selectedRatio = val;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _mbsrRatioButton(
                                        '6:6:6:6',
                                        selectedRatio,
                                        (val) {
                                          setDialogState(() {
                                            selectedRatio = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Duration',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _mbsrDurationButton(
                                        '4 min',
                                        4,
                                        selectedDuration,
                                        (val) {
                                          setDialogState(() {
                                            selectedDuration = val;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _mbsrDurationButton(
                                        '8 min',
                                        8,
                                        selectedDuration,
                                        (val) {
                                          setDialogState(() {
                                            selectedDuration = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 4-7-8 Breathing card
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedType = '478';
                            selectedRatio = '4:7:8';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selectedType == '478'
                                ? primaryColor
                                : const Color(0xFF1A3A2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selectedType == '478'
                                  ? primaryColor
                                  : Colors.grey[700]!,
                              width: selectedType == '478' ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.all_inclusive,
                                    color: selectedType == '478'
                                        ? Colors.white
                                        : primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '4:7:8 Relaxing Breath',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Deep relaxation and stress relief technique.',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedType == '478') ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Duration',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _mbsrDurationButton(
                                        '4 min',
                                        4,
                                        selectedDuration,
                                        (val) {
                                          setDialogState(() {
                                            selectedDuration = val;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _mbsrDurationButton(
                                        '8 min',
                                        8,
                                        selectedDuration,
                                        (val) {
                                          setDialogState(() {
                                            selectedDuration = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Timer display when running - MBSR Breathing Cycle
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A2A),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'MBSR Breathing Cycle',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Time Remaining: ${(remainingTotal / 60).ceil()} min',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatMBSRTime(remainingTotal)} / ${_formatMBSRTime(_totalDurationSeconds[activityId] ?? 0)}',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Circular progress for box breathing
                            if (_breathingType[activityId] == 'box') ...[
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 160,
                                      height: 160,
                                      child: CircularProgressIndicator(
                                        value: _getMBSRBreathingProgress(
                                          activityId,
                                        ),
                                        strokeWidth: 8,
                                        backgroundColor: Colors.grey[800],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          primaryColor,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          currentPhase,
                                          style: GoogleFonts.manrope(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_timerSeconds[activityId] ?? 0}s',
                                          style: GoogleFonts.manrope(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else ...[
                              // For 4-7-8 breathing, show phase text larger
                              Container(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text(
                                      currentPhase,
                                      style: GoogleFonts.manrope(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${_timerSeconds[activityId] ?? 0}s',
                                      style: GoogleFonts.manrope(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Pause/Resume controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.volume_up,
                                    color: Colors.white70,
                                    size: 28,
                                  ),
                                  onPressed: () {},
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      isPaused ? Icons.play_arrow : Icons.pause,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      if (isPaused) {
                                        _resumeMBSRBreathing(
                                          activityId,
                                          setDialogState,
                                        );
                                      } else {
                                        _pauseMBSRBreathing(
                                          activityId,
                                          setDialogState,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    _stopMBSRBreathing(activityId);
                                    Navigator.of(dialogContext).pop();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isRunning) ...[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.manrope(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _startMBSRBreathing(
                        activityId,
                        selectedRatio,
                        selectedType,
                        selectedDuration,
                        setDialogState,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Begin Session',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _mbsrRatioButton(
    String ratio,
    String selectedRatio,
    Function(String) onSelect,
  ) {
    final isSelected = ratio == selectedRatio;
    return GestureDetector(
      onTap: () => onSelect(ratio),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FF88) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          ratio,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isSelected ? const Color(0xFF0D1F14) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _mbsrDurationButton(
    String label,
    int minutes,
    int selectedDuration,
    Function(int) onSelect,
  ) {
    final isSelected = minutes == selectedDuration;
    return GestureDetector(
      onTap: () => onSelect(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FF88) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isSelected ? const Color(0xFF0D1F14) : Colors.white70,
          ),
        ),
      ),
    );
  }

  String _formatMBSRTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _startMBSRBreathing(
    String activityId,
    String ratio,
    String type,
    int durationMinutes,
    StateSetter setDialogState,
  ) async {
    final totalSeconds = durationMinutes * 60;

    setState(() {
      _timerRunning[activityId] = true;
      _breathingRatio[activityId] = ratio;
      _breathingType[activityId] = type;
      _breathingPaused[activityId] = false;
      _breathingCycles[activityId] = 0;
      _totalDurationSeconds[activityId] = totalSeconds;
      _elapsedSeconds[activityId] = 0;
    });

    // Play start sound
    try {
      await _breathingAudioPlayer.play(
        AssetSource('sounds/bell-ringing-05.mp3'),
      );
    } catch (e) {
      // Audio not available, continue silently
      debugPrint('Audio error: $e');
    }

    _runMBSRBreathingCycle(
      activityId,
      ratio,
      type,
      totalSeconds,
      setDialogState,
    );
  }

  void _runMBSRBreathingCycle(
    String activityId,
    String ratio,
    String type,
    int totalDuration,
    StateSetter setDialogState,
  ) {
    final parts = ratio.split(':').map(int.parse).toList();
    final phases = type == '478'
        ? ['Breathe In', 'Hold', 'Breathe Out']
        : ['Breathe In', 'Hold', 'Breathe Out', 'Hold'];
    int phaseIndex = 0;

    void nextPhase() {
      if (!mounted || !(_timerRunning[activityId] ?? false)) return;

      if (_breathingPaused[activityId] ?? false) {
        Future.delayed(const Duration(milliseconds: 100), nextPhase);
        return;
      }

      // Check if total duration reached
      final elapsed = _elapsedSeconds[activityId] ?? 0;
      if (elapsed >= totalDuration) {
        _onMBSRBreathingComplete(activityId);
        return;
      }

      if (phaseIndex >= phases.length) {
        phaseIndex = 0;
      }

      // Use modulo to safely access both arrays
      final safePhaseIndex = phaseIndex % phases.length;
      final duration = parts[safePhaseIndex % parts.length];
      final currentPhase = phases[safePhaseIndex];

      setState(() {
        _breathingPhase[activityId] = currentPhase;
        _timerSeconds[activityId] = duration;
      });
      setDialogState(() {
        _breathingPhase[activityId] = currentPhase;
        _timerSeconds[activityId] = duration;
      });

      // Play phase-specific audio cues
      try {
        if (currentPhase == 'Breathe In') {
          _phaseAudioPlayer.play(AssetSource('sounds/inhale.mp3'));
        } else if (currentPhase == 'Breathe Out') {
          _phaseAudioPlayer.play(AssetSource('sounds/exhale.mp3'));
        } else if (currentPhase == 'Hold') {
          _phaseAudioPlayer.play(AssetSource('sounds/hold.mp3'));
        }
      } catch (e) {
        // Audio not available, continue silently
        debugPrint('Phase audio error: $e');
      }

      _activeTimers[activityId] = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        if (!mounted || !(_timerRunning[activityId] ?? false)) {
          timer.cancel();
          return;
        }

        if (_breathingPaused[activityId] ?? false) {
          return;
        }

        final current = _timerSeconds[activityId] ?? 0;
        final elapsed = _elapsedSeconds[activityId] ?? 0;

        // Update elapsed time
        setState(() {
          _elapsedSeconds[activityId] = elapsed + 1;
        });
        setDialogState(() {
          _elapsedSeconds[activityId] = elapsed + 1;
        });

        if (current <= 1) {
          timer.cancel();
          phaseIndex++;
          nextPhase();
        } else {
          setState(() {
            _timerSeconds[activityId] = current - 1;
          });
          setDialogState(() {
            _timerSeconds[activityId] = current - 1;
          });
        }
      });
    }

    nextPhase();
  }

  double _getMBSRBreathingProgress(String activityId) {
    final ratio = _breathingRatio[activityId] ?? '4:4:4:4';
    final parts = ratio.split(':').map(int.parse).toList();
    final totalCycle = parts.reduce((a, b) => a + b);
    final current = _timerSeconds[activityId] ?? 0;
    final phase = _breathingPhase[activityId] ?? 'Breathe In';

    int elapsed = 0;
    if (phase == 'Breathe In') {
      elapsed = parts[0] - current;
    } else if (phase == 'Hold' && parts.length > 3 && current > parts[2]) {
      elapsed = parts[0] + (parts[1] - current);
    } else if (phase == 'Breathe Out') {
      elapsed =
          parts[0] + parts[1] + (parts.length > 2 ? parts[2] - current : 0);
    } else if (phase == 'Hold' && parts.length > 3) {
      elapsed = parts[0] + parts[1] + parts[2] + (parts[3] - current);
    }

    return (elapsed / totalCycle).clamp(0.0, 1.0);
  }

  void _pauseMBSRBreathing(String activityId, StateSetter setDialogState) {
    setState(() {
      _breathingPaused[activityId] = true;
    });
    setDialogState(() {
      _breathingPaused[activityId] = true;
    });
    _breathingAudioPlayer.pause();
    _phaseAudioPlayer.pause();
  }

  void _resumeMBSRBreathing(String activityId, StateSetter setDialogState) {
    setState(() {
      _breathingPaused[activityId] = false;
    });
    setDialogState(() {
      _breathingPaused[activityId] = false;
    });
    _breathingAudioPlayer.resume();
    _phaseAudioPlayer.resume();
  }

  void _stopMBSRBreathing(String activityId) {
    _activeTimers[activityId]?.cancel();
    _activeTimers[activityId] = null;
    _breathingAudioPlayer.stop();
    _phaseAudioPlayer.stop();
    setState(() {
      _timerRunning[activityId] = false;
      _breathingPaused[activityId] = false;
      _breathingCycles[activityId] = 0;
      _breathingPhase[activityId] = '';
      _timerSeconds[activityId] = 0;
      _totalDurationSeconds[activityId] = 0;
      _elapsedSeconds[activityId] = 0;
      _breathingType[activityId] = '';
    });
  }

  void _onMBSRBreathingComplete(String activityId) {
    // Play completion sound
    try {
      _audioPlayer.play(AssetSource('sounds/bell_complete.mp3'));
    } catch (e) {
      // Audio not available
    }

    _stopMBSRBreathing(activityId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Breathing session completed! 🧘'),
          ],
        ),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============== END MBSR BREATHING METHODS ==============

  @override
  void initState() {
    super.initState();
    _loadWellnessProfile();
    _loadActivities();
    _loadProgress();
    _listenToProgress();
    _loadLastWellnessLog();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    // Dispose MBSR timer resources
    for (var timer in _activeTimers.values) {
      timer?.cancel();
    }
    _audioPlayer.dispose();
    _breathingAudioPlayer.dispose();
    _phaseAudioPlayer.dispose();
    super.dispose();
  }

  /// Load the last wellness log to check 24-hour restriction
  Future<void> _loadLastWellnessLog() async {
    final api = ApiService(baseUrl: cfg.apiBaseUrl);
    try {
      final lastLog = await api.getLastWellnessLog();
      if (mounted) {
        setState(() {
          _wellnessLoading = false;
          if (lastLog != null) {
            _lastWellnessScore = lastLog['score'] as int?;
            if (lastLog['timestamp'] != null) {
              _lastWellnessTime = DateTime.parse(lastLog['timestamp']);
            }
            // Set slider to last score
            if (_lastWellnessScore != null) {
              _happiness = _lastWellnessScore!;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading last wellness log: $e');
      if (mounted) {
        setState(() {
          _wellnessLoading = false;
        });
      }
    }
  }

  /// Check if user can log wellness (24 hours since last log)
  bool get _canLogWellness {
    if (_lastWellnessTime == null) return true;
    final hoursSinceLastLog =
        DateTime.now().difference(_lastWellnessTime!).inHours;
    return hoursSinceLastLog >= 24;
  }

  /// Get hours remaining until next wellness log allowed
  int get _hoursUntilNextLog {
    if (_lastWellnessTime == null) return 0;
    final hoursSinceLastLog =
        DateTime.now().difference(_lastWellnessTime!).inHours;
    return (24 - hoursSinceLastLog).clamp(0, 24);
  }

  /// Load current progress from service
  Future<void> _loadProgress() async {
    try {
      final progress = await ProgressCalculatorService.getTodaysProgress();
      if (mounted) {
        setState(() {
          _completedCount = progress['completedCount'] ?? 0;
          _expectedCount = progress['expectedCount'] ?? 0;
          _completionPercent = progress['completionPercent'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  /// Listen to real-time progress updates
  void _listenToProgress() {
    _progressSub = ProgressCalculatorService.progressStream().listen((
      progress,
    ) {
      if (mounted) {
        setState(() {
          _completedCount = progress['completedCount'] ?? 0;
          _expectedCount = progress['expectedCount'] ?? 0;
          _completionPercent = progress['completionPercent'] ?? 0;
        });
      }
    });
  }

  Future<void> _loadWellnessProfile() async {
    final profile = await WellnessActivityService.getUserProfile();
    if (mounted) {
      setState(() {
        _wellnessProfile = profile;
      });
    }
  }

  Future<void> _loadActivities() async {
    if (!mounted) return;

    setState(() {
      _activitiesLoading = true;
      _activitiesError = null;
    });

    try {
      // First, check if user has wellness profile
      final hasWellnessProfile =
          await WellnessActivityService.hasWellnessProfile();

      List<Map<String, dynamic>> activities;

      if (hasWellnessProfile) {
        // Load ALL wellness activities for the entire day (not just current time slot)
        activities = await WellnessActivityService.getAllDailyActivities();

        // If no wellness activities (shouldn't happen), fallback to API
        if (activities.isEmpty) {
          final api = ApiService(baseUrl: cfg.apiBaseUrl);
          final list = await api.getActivities().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException('Request timed out'),
              );
          activities = List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      } else {
        // No wellness profile - load regular activities from API
        final api = ApiService(baseUrl: cfg.apiBaseUrl);
        final list = await api.getActivities().timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('Request timed out'),
            );
        activities = List<Map<String, dynamic>>.from(
          list.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }

      _activities = activities;

      // Set initial selected time slot to current time slot if not already set
      if (_selectedTimeSlot == null && activities.isNotEmpty) {
        final currentSlot = WellnessActivityService.getCurrentTimeSlot();
        // Find the first activity's time slot that matches current time
        for (final activity in activities) {
          final timeSlot = activity['timeSlot'] as String?;
          if (timeSlot != null &&
              timeSlot.toLowerCase().contains(currentSlot.toLowerCase())) {
            _selectedTimeSlot = timeSlot;
            break;
          }
        }
        // If no match, default to first time slot
        if (_selectedTimeSlot == null && activities.isNotEmpty) {
          _selectedTimeSlot = activities.first['timeSlot'] as String?;
        }
      }

      // Load completion status for each activity from Firestore (source of truth)
      // This ensures activities reset at midnight properly
      final completedIds =
          await WellnessActivityService.getTodaysCompletedActivityIds();

      for (final a in _activities) {
        final id = a['id'] ??
            (a['title'] ?? '').toString().toLowerCase().replaceAll(' ', '_');
        // Check Firestore first, then fall back to local cache
        final isCompleted = completedIds.contains(id);
        _completedCache[id] = isCompleted;

        // Sync local cache with Firestore
        if (isCompleted) {
          await CompletionStore.markCompleted(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _activitiesLoading = false;
        _activitiesError = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _activitiesLoading = false;
        _activitiesError =
            'Request timed out. Please check your internet connection and try again.';
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _activitiesLoading = false;
        _activitiesError =
            'No internet connection. Please connect to the internet and try again.';
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _activitiesLoading = false;
        _activitiesError =
            'Server returned unexpected data. Please try again later.';
      });
    } on HttpException catch (e) {
      if (!mounted) return;
      setState(() {
        _activitiesLoading = false;
        _activitiesError =
            'Server error: ${e.message}. Please try again later.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activitiesLoading = false;
        _activitiesError = 'Something went wrong. Please try again.';
      });
    }
  }
}
