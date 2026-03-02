/// Model for wellness schedule based on user profile and time slots
class WellnessSchedule {
  final String profile;
  final Map<String, List<WellnessActivity>> weekdaySchedule;
  final List<WellnessActivity> weekendActivities;

  WellnessSchedule({
    required this.profile,
    required this.weekdaySchedule,
    required this.weekendActivities,
  });

  factory WellnessSchedule.fromJson(Map<String, dynamic> json) {
    final weekdaySchedule = <String, List<WellnessActivity>>{};
    (json['weekdaySchedule'] as Map<String, dynamic>?)?.forEach((key, value) {
      weekdaySchedule[key] = (value as List)
          .map((e) => WellnessActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    return WellnessSchedule(
      profile: json['profile'] as String,
      weekdaySchedule: weekdaySchedule,
      weekendActivities: (json['weekendActivities'] as List?)
              ?.map((e) => WellnessActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    final weekdayScheduleJson = <String, dynamic>{};
    weekdaySchedule.forEach((key, value) {
      weekdayScheduleJson[key] = value.map((e) => e.toJson()).toList();
    });

    return {
      'profile': profile,
      'weekdaySchedule': weekdayScheduleJson,
      'weekendActivities': weekendActivities.map((e) => e.toJson()).toList(),
    };
  }
}

/// Individual wellness activity with details
class WellnessActivity {
  final String title;
  final String? description;
  final String? info;
  final String? youtubeUrl;
  final List<String>? tips;
  final String? category; // exercise, nutrition, mindfulness, etc.

  WellnessActivity({
    required this.title,
    this.description,
    this.info,
    this.youtubeUrl,
    this.tips,
    this.category,
  });

  factory WellnessActivity.fromJson(Map<String, dynamic> json) {
    return WellnessActivity(
      title: json['title'] as String,
      description: json['description'] as String?,
      info: json['info'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      tips: (json['tips'] as List?)?.cast<String>(),
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      if (info != null) 'info': info,
      if (youtubeUrl != null) 'youtubeUrl': youtubeUrl,
      if (tips != null) 'tips': tips,
      if (category != null) 'category': category,
    };
  }
}

/// User profile types
enum UserProfile {
  work('Work', 'Professionals looking for work‑centric wellness'),
  academic('Academic', 'Students / academics balancing studies'),
  housewife('Housewife', 'Homemakers prioritizing family wellness');

  final String displayName;
  final String description;

  const UserProfile(this.displayName, this.description);
}

/// Time slots for weekday schedule
class TimeSlot {
  static const morning = '6am-9am';
  static const midDay = '9am-2pm';
  static const afternoon = '2:30pm-6pm';
  static const evening = '7pm-10pm';

  static List<String> get all => [morning, midDay, afternoon, evening];

  static String getDisplayName(String slot) {
    switch (slot) {
      case morning:
        return 'Morning Routine';
      case midDay:
        return 'Mid-Day Focus';
      case afternoon:
        return 'Afternoon Break';
      case evening:
        return 'Evening Wind Down';
      default:
        return slot;
    }
  }

  static String getIcon(String slot) {
    switch (slot) {
      case morning:
        return '🌅';
      case midDay:
        return '☀️';
      case afternoon:
        return '🌤️';
      case evening:
        return '🌙';
      default:
        return '⏰';
    }
  }
}
