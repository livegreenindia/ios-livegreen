// Simple in-memory store to keep the most-recent local submissions so the
// UI can show an optimistic fallback when the server returns an empty
// series (useful during development or when the backend has not yet
// propagated recent writes).
class RecentDataStore {
  /// Last recorded happiness score (1-10)
  static int? lastHappiness;

  /// When the last happiness was recorded
  static DateTime? lastHappinessAt;

  /// Last recorded completion percent (0-100)
  static int? lastCompletionPercent;

  /// When the last completion was recorded
  static DateTime? lastActivityAt;

  static void recordHappiness(int score, [DateTime? at]) {
    lastHappiness = score;
    lastHappinessAt = at ?? DateTime.now();
  }

  static void recordActivityComplete(int percent, [DateTime? at]) {
    lastCompletionPercent = percent;
    lastActivityAt = at ?? DateTime.now();
  }

  /// Return whether there is recent data within the requested range.
  /// Range values expected: 'week', 'month', 'year'
  static bool hasRecentForRange(String range) {
    final now = DateTime.now();
    DateTime cutoff;
    if (range == 'week') {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (range == 'month') {
      cutoff = now.subtract(const Duration(days: 30));
    } else {
      cutoff = now.subtract(const Duration(days: 365));
    }

    final recentHap = lastHappinessAt != null && lastHappinessAt!.isAfter(cutoff);
    final recentAct = lastActivityAt != null && lastActivityAt!.isAfter(cutoff);
    return recentHap || recentAct;
  }

  /// Generate a simple synthesized series covering the requested range.
  /// Returns a list of maps with keys: day, happiness, completionPercent.
  /// `range` expects 'week' | 'month' | 'year'. This is purely a client-side
  /// fallback for UX when the backend returns no data.
  static List<Map<String, dynamic>> generateFallbackSeries(String range) {
    if (range == 'week') {
      // 7 days: Mon..Sun (use short names)
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days.map((d) => {
        'day': d,
        'happiness': lastHappiness ?? 0,
        'activities': lastCompletionPercent != null ? (lastCompletionPercent! / 10).round() : 0,
      }).toList();
    } else if (range == 'month') {
      // 4 weeks: Week 1..4
      return List.generate(4, (i) => {
        'day': 'Week ${i + 1}',
        'happiness': lastHappiness ?? 0,
        'activities': lastCompletionPercent != null ? (lastCompletionPercent! / 10).round() : 0,
      });
    } else {
      // Yearly: 12 months
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months.map((m) => {
        'day': m,
        'happiness': lastHappiness ?? 0,
        'activities': lastCompletionPercent != null ? (lastCompletionPercent! / 10).round() : 0,
      }).toList();
    }
  }
}
