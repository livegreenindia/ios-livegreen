import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'wellness_activity_service.dart';

/// Service to calculate user progress based on completed wellness activities
class ProgressCalculatorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Expected activity counts per profile
  /// Based on wellness_schedule_data.dart
  static const Map<String, Map<String, int>> _activityCounts = {
    'Working': {'weekday': 20, 'weekend': 6},
    'Student': {'weekday': 20, 'weekend': 6},
    'Housewife': {'weekday': 20, 'weekend': 6},
    'Retired': {'weekday': 20, 'weekend': 6},
    'default': {'weekday': 10, 'weekend': 5},
  };

  /// Check if a date is weekend
  static bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Get expected activity count for a given profile and date
  static int getExpectedActivityCount(String? profile, DateTime date) {
    final counts = _activityCounts[profile] ?? _activityCounts['default']!;
    return _isWeekend(date) ? counts['weekend']! : counts['weekday']!;
  }

  /// Get today's progress for the current user
  /// Returns: {completedCount, expectedCount, completionPercent, profile, isWeekend}
  static Future<Map<String, dynamic>> getTodaysProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _defaultProgress();
      }

      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get user's wellness profile
      final profile = await WellnessActivityService.getUserProfile() ?? 'default';

      // Get expected activity count
      final expectedCount = getExpectedActivityCount(profile, today);

      // Count completed activities for today
      // Note: Backend stores date as 'date' field (YYYY-MM-DD format)
      final completionsSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('completions')
          .where('date', isEqualTo: dateStr)
          .get();

      final completedCount = completionsSnap.size;
      
      // Calculate percentage (cap at 100%)
      final completionPercent = expectedCount == 0
          ? 0
          : (completedCount / expectedCount * 100).clamp(0, 100).round();

      return {
        'completedCount': completedCount,
        'expectedCount': expectedCount,
        'completionPercent': completionPercent,
        'profile': profile,
        'isWeekend': _isWeekend(today),
        'date': dateStr,
      };
    } catch (e) {
      debugPrint('Error calculating today\'s progress: $e');
      return _defaultProgress();
    }
  }

  /// Get progress for a specific date range
  /// Returns list of daily progress entries
  static Future<List<Map<String, dynamic>>> getProgressForRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user's wellness profile
      final profile = await WellnessActivityService.getUserProfile() ?? 'default';

      final results = <Map<String, dynamic>>[];
      DateTime current = startDate;

      while (!current.isAfter(endDate)) {
        final dateStr = '${current.year.toString().padLeft(4, '0')}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';

        // Get completed activities for this date
        // Note: Backend stores date as 'date' field (YYYY-MM-DD format)
        final completionsSnap = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('completions')
            .where('date', isEqualTo: dateStr)
            .get();

        final completedCount = completionsSnap.size;
        final expectedCount = getExpectedActivityCount(profile, current);
        final completionPercent = expectedCount == 0
            ? 0
            : (completedCount / expectedCount * 100).clamp(0, 100).round();

        results.add({
          'date': dateStr,
          'completedCount': completedCount,
          'expectedCount': expectedCount,
          'completionPercent': completionPercent,
          'isWeekend': _isWeekend(current),
        });

        current = current.add(const Duration(days: 1));
      }

      return results;
    } catch (e) {
      debugPrint('Error getting progress for range: $e');
      return [];
    }
  }

  /// Get weekly summary (last 7 days)
  static Future<Map<String, dynamic>> getWeeklySummary() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 6));
      
      final dailyProgress = await getProgressForRange(
        startDate: startDate,
        endDate: endDate,
      );

      if (dailyProgress.isEmpty) {
        return {
          'totalCompleted': 0,
          'totalExpected': 0,
          'avgCompletionPercent': 0,
          'daysTracked': 0,
          'dailyProgress': [],
        };
      }

      int totalCompleted = 0;
      int totalExpected = 0;
      double totalPercent = 0;

      for (final day in dailyProgress) {
        totalCompleted += (day['completedCount'] as int?) ?? 0;
        totalExpected += (day['expectedCount'] as int?) ?? 0;
        totalPercent += (day['completionPercent'] as int?) ?? 0;
      }

      final avgPercent = dailyProgress.isNotEmpty
          ? (totalPercent / dailyProgress.length).round()
          : 0;

      return {
        'totalCompleted': totalCompleted,
        'totalExpected': totalExpected,
        'avgCompletionPercent': avgPercent,
        'daysTracked': dailyProgress.length,
        'dailyProgress': dailyProgress,
      };
    } catch (e) {
      debugPrint('Error getting weekly summary: $e');
      return {
        'totalCompleted': 0,
        'totalExpected': 0,
        'avgCompletionPercent': 0,
        'daysTracked': 0,
        'dailyProgress': [],
      };
    }
  }

  /// Get monthly summary
  static Future<Map<String, dynamic>> getMonthlySummary() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      
      final dailyProgress = await getProgressForRange(
        startDate: startDate,
        endDate: now,
      );

      if (dailyProgress.isEmpty) {
        return {
          'totalCompleted': 0,
          'totalExpected': 0,
          'avgCompletionPercent': 0,
          'daysTracked': 0,
          'dailyProgress': [],
        };
      }

      int totalCompleted = 0;
      int totalExpected = 0;
      double totalPercent = 0;

      for (final day in dailyProgress) {
        totalCompleted += (day['completedCount'] as int?) ?? 0;
        totalExpected += (day['expectedCount'] as int?) ?? 0;
        totalPercent += (day['completionPercent'] as int?) ?? 0;
      }

      final avgPercent = dailyProgress.isNotEmpty
          ? (totalPercent / dailyProgress.length).round()
          : 0;

      return {
        'totalCompleted': totalCompleted,
        'totalExpected': totalExpected,
        'avgCompletionPercent': avgPercent,
        'daysTracked': dailyProgress.length,
        'dailyProgress': dailyProgress,
      };
    } catch (e) {
      debugPrint('Error getting monthly summary: $e');
      return {
        'totalCompleted': 0,
        'totalExpected': 0,
        'avgCompletionPercent': 0,
        'daysTracked': 0,
        'dailyProgress': [],
      };
    }
  }

  /// Get activity completion details for today
  /// Returns list of activities with completion status
  static Future<List<Map<String, dynamic>>> getTodaysActivityDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get all today's activities
      final allActivities = await WellnessActivityService.getAllDailyActivities();
      if (allActivities.isEmpty) return [];

      // Get today's completions
      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Note: Backend stores date as 'date' field (YYYY-MM-DD format)
      final completionsSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('completions')
          .where('date', isEqualTo: dateStr)
          .get();

      final completedIds = completionsSnap.docs
          .map((doc) => doc.data()['activityId'] as String?)
          .where((id) => id != null)
          .toSet();

      // Mark activities as completed or not
      return allActivities.map((activity) {
        final id = activity['id'] as String?;
        return {
          ...activity,
          'completed': id != null && completedIds.contains(id),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting activity details: $e');
      return [];
    }
  }

  /// Stream for real-time progress updates
  static Stream<Map<String, dynamic>> progressStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(_defaultProgress());
    }

    final today = DateTime.now();
    final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Note: Backend stores date as 'date' field (YYYY-MM-DD format)
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('completions')
        .where('date', isEqualTo: dateStr)
        .snapshots()
        .asyncMap((snapshot) async {
          final profile = await WellnessActivityService.getUserProfile() ?? 'default';
          final expectedCount = getExpectedActivityCount(profile, today);
          final completedCount = snapshot.size;
          final completionPercent = expectedCount == 0
              ? 0
              : (completedCount / expectedCount * 100).clamp(0, 100).round();

          return {
            'completedCount': completedCount,
            'expectedCount': expectedCount,
            'completionPercent': completionPercent,
            'profile': profile,
            'isWeekend': _isWeekend(today),
            'date': dateStr,
          };
        });
  }

  static Map<String, dynamic> _defaultProgress() {
    return {
      'completedCount': 0,
      'expectedCount': 0,
      'completionPercent': 0,
      'profile': 'default',
      'isWeekend': false,
      'date': '',
    };
  }
}
