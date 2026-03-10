import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/wellness_schedule.dart';
import '../config/wellness_schedule_data.dart';

class WellnessScheduleScreen extends StatefulWidget {
  final String profile;

  const WellnessScheduleScreen({super.key, required this.profile});

  @override
  State<WellnessScheduleScreen> createState() => _WellnessScheduleScreenState();
}

class _WellnessScheduleScreenState extends State<WellnessScheduleScreen> with SingleTickerProviderStateMixin {
  late WellnessSchedule _schedule;
  late TabController _tabController;
  bool _showWeekend = false;

  @override
  void initState() {
    super.initState();
    _schedule = WellnessScheduleData.getScheduleForProfile(widget.profile);
    _tabController = TabController(length: TimeSlot.all.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getCurrentTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 9) return TimeSlot.morning;
    if (hour >= 9 && hour < 14) return TimeSlot.midDay;
    if (hour >= 14 && hour < 18) return TimeSlot.afternoon;
    return TimeSlot.evening;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeekend = DateTime.now().weekday >= 6;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Wellness Plan',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFF2e7d32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showProfileInfo(context, isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(isDark),
          _buildDayTypeToggle(isDark, isWeekend),
          if (!_showWeekend) _buildTimeSlotTabs(isDark),
          Expanded(
            child: _showWeekend
                ? _buildWeekendActivities(isDark)
                : _buildWeekdayActivities(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : const Color(0xFF2e7d32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getProfileIcon(),
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
                  widget.profile,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Personalized wellness activities',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTypeToggle(bool isDark, bool isWeekend) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeekend = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showWeekend
                      ? const Color(0xFF2e7d32)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: !_showWeekend
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Monday - Friday',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: !_showWeekend ? FontWeight.bold : FontWeight.normal,
                        color: !_showWeekend
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeekend = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showWeekend
                      ? const Color(0xFF2e7d32)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wb_sunny,
                      size: 16,
                      color: _showWeekend
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saturday & Sunday',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: _showWeekend ? FontWeight.bold : FontWeight.normal,
                        color: _showWeekend
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotTabs(bool isDark) {
    final currentSlot = _getCurrentTimeSlot();
    final currentIndex = TimeSlot.all.indexOf(currentSlot);
    if (_tabController.index != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(currentIndex);
      });
    }

    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF2e7d32),
        labelColor: const Color(0xFF2e7d32),
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        tabs: TimeSlot.all.map((slot) {
          final isActive = slot == currentSlot;
          return Tab(
            child: Row(
              children: [
                Text(TimeSlot.getIcon(slot)),
                const SizedBox(width: 4),
                Text(TimeSlot.getDisplayName(slot)),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2e7d32),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekdayActivities(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: TimeSlot.all.map((slot) {
        final activities = _schedule.weekdaySchedule[slot] ?? [];
        return _buildActivityList(activities, isDark, slot);
      }).toList(),
    );
  }

  Widget _buildWeekendActivities(bool isDark) {
    return _buildActivityList(_schedule.weekendActivities, isDark, 'Weekend');
  }

  Widget _buildActivityList(List<WellnessActivity> activities, bool isDark, String timeSlot) {
    if (activities.isEmpty) {
      return Center(
        child: Text(
          'No activities scheduled',
          style: GoogleFonts.manrope(
            fontSize: 16,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(activities[index], isDark, index);
      },
    );
  }

  Widget _buildActivityCard(WellnessActivity activity, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showActivityInfo(context, activity, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(activity.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(activity.category),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (activity.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          activity.description!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showActivityInfo(context, activity, isDark),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2e7d32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2e7d32),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActivityInfo(BuildContext context, WellnessActivity activity, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(activity.category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getCategoryIcon(activity.category),
                            color: _getCategoryColor(activity.category),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            activity.title,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (activity.info != null) ...[
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
                        activity.info!,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                    if (activity.tips != null && activity.tips!.isNotEmpty) ...[
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
                      ...activity.tips!.map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(activity.category),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    if (activity.youtubeUrl != null) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _launchURL(activity.youtubeUrl!),
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
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileInfo(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'About Your Wellness Plan',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'This personalized wellness schedule is designed specifically for your lifestyle as a ${widget.profile}. '
          'Each activity is chosen to support your physical health, mental well-being, and connection with nature. '
          '\n\nTap the "i" icon on any activity to learn more about its benefits and get helpful tips!',
          style: GoogleFonts.manrope(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it!',
              style: GoogleFonts.manrope(
                color: const Color(0xFF2e7d32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getProfileIcon() {
    // all profiles use work icon for now; academic uses school too
    switch (widget.profile) {
      case 'Work':
        return Icons.business_center;
      case 'Academic':
        return Icons.school;
      case 'Housewife':
        return Icons.home;
      default:
        return Icons.business_center;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'health':
        return const Color(0xFF4CAF50);
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
        return const Color(0xFFE91E63);
      case 'relaxation':
        return const Color(0xFF00BCD4);
      case 'sleep_hygiene':
        return const Color(0xFF673AB7);
      default:
        return const Color(0xFF2e7d32);
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'health':
        return Icons.favorite;
      case 'fitness':
        return Icons.fitness_center;
      case 'nutrition':
        return Icons.restaurant;
      case 'mindfulness':
        return Icons.self_improvement;
      case 'nature':
        return Icons.park;
      case 'productivity':
        return Icons.work;
      case 'social':
        return Icons.people;
      case 'relaxation':
        return Icons.spa;
      case 'sleep_hygiene':
        return Icons.bedtime;
      default:
        return Icons.star;
    }
  }
}
