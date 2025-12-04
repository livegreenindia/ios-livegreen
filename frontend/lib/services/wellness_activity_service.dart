import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/wellness_schedule.dart';
import '../config/wellness_schedule_data.dart';

/// Service to provide wellness activities based on user profile and time
class WellnessActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user's wellness profile from Firestore
  static Future<String?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['wellness_profile'] as String?;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
    return null;
  }

  /// Get current time slot based on time of day
  static String getCurrentTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 9) {
      return TimeSlot.morning;
    } else if (hour >= 9 && hour < 14) {
      return TimeSlot.midDay;
    } else if (hour >= 14 && hour < 18) {
      return TimeSlot.afternoon;
    } else {
      return TimeSlot.evening;
    }
  }

  /// Check if today is weekend
  static bool isWeekend() {
    final weekday = DateTime.now().weekday;
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  /// Get wellness activities for today based on user profile
  /// Returns list formatted for Activity page compatibility
  static Future<List<Map<String, dynamic>>> getTodaysActivities() async {
    try {
      // Get user's wellness profile
      final profileName = await getUserProfile();
      if (profileName == null) {
        // No profile set - return empty to show generic activities
        return [];
      }

      // Get schedule for this profile
      final allSchedules = WellnessScheduleData.getAllSchedules();
      final schedule = allSchedules[profileName];
      if (schedule == null) return [];

      List<WellnessActivity> activities;

      // Get activities based on day type
      if (isWeekend()) {
        activities = schedule.weekendActivities;
      } else {
        final timeSlot = getCurrentTimeSlot();
        activities = schedule.weekdaySchedule[timeSlot] ?? [];
      }

      // Convert to Activity page format
      return activities.map((activity) {
        return {
          'id': _generateActivityId(activity.title),
          'title': activity.title,
          'subtitle': activity.description ?? _getCategoryDescription(activity.category),
          'description': activity.info ?? activity.description,
          'icon': _getCategoryIcon(activity.category),
          'weight': 10, // Default weight for wellness activities
          'category': activity.category,
          'youtubeUrl': activity.youtubeUrl,
          'tips': activity.tips,
          'isWellnessActivity': true, // Flag to identify wellness activities
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading wellness activities: $e');
      return [];
    }
  }

  /// Get ALL wellness activities for the entire day grouped by time slot
  /// Returns activities with 'timeSlot' field for grouping
  static Future<List<Map<String, dynamic>>> getAllDailyActivities() async {
    try {
      // Get user's wellness profile
      final profileName = await getUserProfile();
      if (profileName == null) {
        // No profile set - return empty to show generic activities
        return [];
      }

      // Get schedule for this profile
      final allSchedules = WellnessScheduleData.getAllSchedules();
      final schedule = allSchedules[profileName];
      if (schedule == null) return [];

      final allActivities = <Map<String, dynamic>>[];

      // Get activities based on day type
      if (isWeekend()) {
        // Weekend - just mark all as weekend activities
        for (final activity in schedule.weekendActivities) {
          allActivities.add({
            'id': _generateActivityId(activity.title),
            'title': activity.title,
            'subtitle': activity.description ?? _getCategoryDescription(activity.category),
            'description': activity.info ?? activity.description,
            'icon': _getCategoryIcon(activity.category),
            'weight': 10,
            'category': activity.category,
            'youtubeUrl': activity.youtubeUrl,
            'tips': activity.tips,
            'isWellnessActivity': true,
            'timeSlot': 'Weekend',
            'timeSlotOrder': 0,
          });
        }
      } else {
        // Weekday - get activities for ALL time slots
        final timeSlots = [
          TimeSlot.morning,
          TimeSlot.midDay,
          TimeSlot.afternoon,
          TimeSlot.evening,
        ];

        final timeSlotNames = {
          TimeSlot.morning: 'Morning (6am-9am)',
          TimeSlot.midDay: 'Mid-Day (9am-2pm)',
          TimeSlot.afternoon: 'Afternoon (2:30pm-6pm)',
          TimeSlot.evening: 'Evening (7pm-10pm)',
        };

        for (int i = 0; i < timeSlots.length; i++) {
          final timeSlot = timeSlots[i];
          final activities = schedule.weekdaySchedule[timeSlot] ?? [];
          
          for (final activity in activities) {
            allActivities.add({
              'id': _generateActivityId(activity.title),
              'title': activity.title,
              'subtitle': activity.description ?? _getCategoryDescription(activity.category),
              'description': activity.info ?? activity.description,
              'icon': _getCategoryIcon(activity.category),
              'weight': 10,
              'category': activity.category,
              'youtubeUrl': activity.youtubeUrl,
              'tips': activity.tips,
              'isWellnessActivity': true,
              'timeSlot': timeSlotNames[timeSlot] ?? timeSlot,
              'timeSlotOrder': i, // For sorting
            });
          }
        }
      }

      return allActivities;
    } catch (e) {
      debugPrint('Error loading all daily wellness activities: $e');
      return [];
    }
  }

  /// Generate consistent activity ID from title
  static String _generateActivityId(String title) {
    return 'wellness_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
  }

  /// Get icon name for category
  static String _getCategoryIcon(String? category) {
    switch (category) {
      case 'health':
        return 'favorite';
      case 'fitness':
        return 'fitness_center';
      case 'nutrition':
        return 'restaurant';
      case 'mindfulness':
        return 'self_improvement';
      case 'nature':
        return 'park';
      case 'productivity':
        return 'work';
      case 'social':
        return 'people';
      case 'relaxation':
        return 'spa';
      case 'sleep_hygiene':
        return 'bedtime';
      case 'learning':
        return 'school';
      case 'creativity':
        return 'palette';
      case 'mental_fitness':
        return 'psychology';
      default:
        return 'nature_people';
    }
  }

  /// Get description for category
  static String _getCategoryDescription(String? category) {
    switch (category) {
      case 'health':
        return 'Improve your physical health';
      case 'fitness':
        return 'Stay active and fit';
      case 'nutrition':
        return 'Nourish your body';
      case 'mindfulness':
        return 'Practice mindfulness';
      case 'nature':
        return 'Connect with nature';
      case 'productivity':
        return 'Boost productivity';
      case 'social':
        return 'Build connections';
      case 'relaxation':
        return 'Relax and unwind';
      case 'sleep_hygiene':
        return 'Improve sleep quality';
      case 'learning':
        return 'Learn something new';
      case 'creativity':
        return 'Express creativity';
      case 'mental_fitness':
        return 'Strengthen mental health';
      default:
        return 'Wellness activity';
    }
  }

  /// Get time slot display name
  static String getTimeSlotDisplayName() {
    final timeSlot = getCurrentTimeSlot();
    switch (timeSlot) {
      case TimeSlot.morning:
        return 'Morning (6am-9am)';
      case TimeSlot.midDay:
        return 'Mid-Day (9am-2pm)';
      case TimeSlot.afternoon:
        return 'Afternoon (2:30pm-6pm)';
      case TimeSlot.evening:
        return 'Evening (7pm-10pm)';
      default:
        return 'Today';
    }
  }

  /// Check if user has set wellness profile
  static Future<bool> hasWellnessProfile() async {
    final profile = await getUserProfile();
    return profile != null;
  }

  /// Get set of activity IDs completed today from Firestore
  /// This is the source of truth for completion status
  static Future<Set<String>> getTodaysCompletedActivityIds() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('completions')
          .where('date', isEqualTo: dateStr)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['activityId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
    } catch (e) {
      debugPrint('Error getting today\'s completed activities: $e');
      return {};
    }
  }
}
