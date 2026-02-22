import 'package:flutter/foundation.dart';

@immutable
class MindfulnessBellSettings {
  const MindfulnessBellSettings({
    required this.sound,
    required this.interval,
    required this.muteWhenFlightMode,
    required this.muteWhenSilentMode,
    required this.muteWhenDoNotDisturb,
    required this.quietHoursEnabled,
    required this.quietHoursStartMinutes,
    required this.quietHoursEndMinutes,
  });

  final AlarmSound sound;
  final ReminderInterval interval;
  final bool muteWhenFlightMode;
  final bool muteWhenSilentMode;
  final bool muteWhenDoNotDisturb;
  final bool quietHoursEnabled;
  final int quietHoursStartMinutes; // Minutes from midnight (0-1439)
  final int quietHoursEndMinutes; // Minutes from midnight (0-1439)

  static const defaults = MindfulnessBellSettings(
    sound: AlarmSound.bell,
    interval: ReminderInterval.minutes15,
    muteWhenFlightMode: true,
    muteWhenSilentMode: true,
    muteWhenDoNotDisturb: true,
    quietHoursEnabled: false,
    quietHoursStartMinutes: 1320, // 10 PM (22:00)
    quietHoursEndMinutes: 420, // 7 AM (07:00)
  );

  MindfulnessBellSettings copyWith({
    AlarmSound? sound,
    ReminderInterval? interval,
    bool? muteWhenFlightMode,
    bool? muteWhenSilentMode,
    bool? muteWhenDoNotDisturb,
    bool? quietHoursEnabled,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
  }) {
    return MindfulnessBellSettings(
      sound: sound ?? this.sound,
      interval: interval ?? this.interval,
      muteWhenFlightMode: muteWhenFlightMode ?? this.muteWhenFlightMode,
      muteWhenSilentMode: muteWhenSilentMode ?? this.muteWhenSilentMode,
      muteWhenDoNotDisturb: muteWhenDoNotDisturb ?? this.muteWhenDoNotDisturb,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartMinutes:
          quietHoursStartMinutes ?? this.quietHoursStartMinutes,
      quietHoursEndMinutes: quietHoursEndMinutes ?? this.quietHoursEndMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sound': sound.name,
      'interval': interval.name,
      'muteWhenFlightMode': muteWhenFlightMode,
      'muteWhenSilentMode': muteWhenSilentMode,
      'muteWhenDoNotDisturb': muteWhenDoNotDisturb,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStartMinutes': quietHoursStartMinutes,
      'quietHoursEndMinutes': quietHoursEndMinutes,
    };
  }

  Map<String, dynamic> toWorkInputData() {
    return {
      'sound': sound.name,
      'intervalMinutes': interval.duration.inMinutes,
      'muteWhenFlightMode': muteWhenFlightMode,
      'muteWhenSilentMode': muteWhenSilentMode,
      'muteWhenDoNotDisturb': muteWhenDoNotDisturb,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStartMinutes': quietHoursStartMinutes,
      'quietHoursEndMinutes': quietHoursEndMinutes,
    };
  }

  factory MindfulnessBellSettings.fromMap(Map<String, dynamic> map) {
    final soundKey = map['sound'] as String?;
    final intervalKey = map['interval'] as String?;

    return MindfulnessBellSettings(
      sound: AlarmSoundX.fromName(soundKey),
      interval: ReminderIntervalX.fromName(intervalKey),
      muteWhenFlightMode: map['muteWhenFlightMode'] as bool? ?? true,
      muteWhenSilentMode: map['muteWhenSilentMode'] as bool? ?? true,
      muteWhenDoNotDisturb: map['muteWhenDoNotDisturb'] as bool? ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      quietHoursStartMinutes: map['quietHoursStartMinutes'] as int? ?? 1320,
      quietHoursEndMinutes: map['quietHoursEndMinutes'] as int? ?? 420,
    );
  }

  factory MindfulnessBellSettings.fromWorkInputData(Map<String, dynamic> map) {
    final soundKey = map['sound'] as String?;
    final minutes = map['intervalMinutes'] as int? ?? 15;

    return MindfulnessBellSettings(
      sound: AlarmSoundX.fromName(soundKey),
      interval: ReminderIntervalX.fromMinutes(minutes),
      muteWhenFlightMode: map['muteWhenFlightMode'] as bool? ?? true,
      muteWhenSilentMode: map['muteWhenSilentMode'] as bool? ?? true,
      muteWhenDoNotDisturb: map['muteWhenDoNotDisturb'] as bool? ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      quietHoursStartMinutes: map['quietHoursStartMinutes'] as int? ?? 1320,
      quietHoursEndMinutes: map['quietHoursEndMinutes'] as int? ?? 420,
    );
  }
}

enum AlarmSound { bell, birdSong, vibrateOnly }

extension AlarmSoundX on AlarmSound {
  String get label {
    switch (this) {
      case AlarmSound.bell:
        return 'Bell';
      case AlarmSound.birdSong:
        return 'Bird Song';
      case AlarmSound.vibrateOnly:
        return 'Vibrate Only';
    }
  }

  static AlarmSound fromName(String? name) {
    return AlarmSound.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AlarmSound.bell,
    );
  }
}

enum ReminderInterval {
  minutes15,
  minutes30,
  minutes45,
  hour1,
  hours2,
}

extension ReminderIntervalX on ReminderInterval {
  Duration get duration {
    switch (this) {
      case ReminderInterval.minutes15:
        return const Duration(minutes: 15);
      case ReminderInterval.minutes30:
        return const Duration(minutes: 30);
      case ReminderInterval.minutes45:
        return const Duration(minutes: 45);
      case ReminderInterval.hour1:
        return const Duration(hours: 1);
      case ReminderInterval.hours2:
        return const Duration(hours: 2);
    }
  }

  String get label {
    switch (this) {
      case ReminderInterval.minutes15:
        return '15 minutes';
      case ReminderInterval.minutes30:
        return '30 minutes';
      case ReminderInterval.minutes45:
        return '45 minutes';
      case ReminderInterval.hour1:
        return '1 hour';
      case ReminderInterval.hours2:
        return '2 hours';
    }
  }

  static ReminderInterval fromName(String? name) {
    return ReminderInterval.values.firstWhere(
      (value) => value.name == name,
      orElse: () => ReminderInterval.minutes15,
    );
  }

  static ReminderInterval fromMinutes(int minutes) {
    switch (minutes) {
      case 15:
        return ReminderInterval.minutes15;
      case 30:
        return ReminderInterval.minutes30;
      case 45:
        return ReminderInterval.minutes45;
      case 60:
        return ReminderInterval.hour1;
      case 120:
        return ReminderInterval.hours2;
      default:
        return ReminderInterval.minutes15;
    }
  }
}
