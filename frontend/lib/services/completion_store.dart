import 'package:shared_preferences/shared_preferences.dart';

class CompletionStore {
  // Key prefix to avoid collisions
  static const _prefix = 'activity_completed:';

  /// Format a DateTime to YYYY-MM-DD in local time
  static String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Mark an activity as completed at [at] (default now). Stores the local date.
  static Future<void> markCompleted(String activityId, [DateTime? at]) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _formatDate(at ?? DateTime.now());
    await prefs.setString('$_prefix$activityId', date);
  }

  /// Check whether the activity was completed today (local date matches).
  static Future<bool> isCompletedToday(String activityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('$_prefix$activityId');
      if (stored == null) return false;
      final today = _formatDate(DateTime.now());
      return stored == today;
    } catch (_) {
      return false;
    }
  }

  /// Clear completion for an activity (useful for testing)
  static Future<void> clear(String activityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$activityId');
  }

  /// Clear all activity completions (use when user logs in for first time or logs out)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_prefix)) {
        await prefs.remove(key);
      }
    }
  }
}
