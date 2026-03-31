import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/mindfulness_bell_settings.dart';
import 'audio_streaming_service.dart';
import 'device_audio_mode_service.dart';
import 'mindfulness_bell_settings_service.dart';

class MindfulnessBellScheduler {
  // Use a versioned channel id so sound config updates apply on existing installs.
  static const String _audioChannelIdBell = 'mindfulness_bell_audio_bell_v3';
  static const String _audioChannelIdBird = 'mindfulness_bell_audio_bird_v3';
  static const String _vibrateChannelId = 'mindfulness_bell_vibrate';
  static const int _notificationIdBase = 67000;
  static const int _maxScheduledReminders = 96;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static bool _notificationsInitialized = false;

  static Future<void> initialize() async {
    if (_notificationsInitialized) {
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);

    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final notificationsEnabled =
        await androidImplementation?.areNotificationsEnabled();
    if (notificationsEnabled == false) {
      await androidImplementation?.requestNotificationsPermission();
    }

    var canScheduleExact =
        await androidImplementation?.canScheduleExactNotifications();
    if (canScheduleExact == false) {
      await androidImplementation?.requestExactAlarmsPermission();
      canScheduleExact =
          await androidImplementation?.canScheduleExactNotifications();
    }

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _audioChannelIdBell,
        'Mindfulness Bell (Bell Sound)',
        description: 'Mindfulness reminders with bell sound',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('bell_ringing'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      ),
    );

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _audioChannelIdBird,
        'Mindfulness Bell (Bird Song)',
        description: 'Mindfulness reminders with bird song',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('forest_sound'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      ),
    );

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _vibrateChannelId,
        'Mindfulness Bell Vibrate Only',
        description: 'Mindfulness reminders with vibration only',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        'Mindfulness Bell init: notificationsEnabled=$notificationsEnabled, canScheduleExact=${canScheduleExact ?? false}',
      );
    }

    _notificationsInitialized = true;
  }

  static Future<void> startRecurringReminder(
    MindfulnessBellSettings settings,
  ) async {
    await initialize();
    await cancelRecurringReminder();

    final scheduleAnchor = tz.TZDateTime.now(tz.local);
    final reminderInterval = settings.interval.duration;
    final alwaysVibrateOnly = settings.sound == AlarmSound.vibrateOnly;
    var scheduleMode = await _resolveScheduleMode();

    if (kDebugMode && reminderInterval.inSeconds <= 60) {
      debugPrint(
        'Mindfulness Bell test mode enabled: scheduling every ${reminderInterval.inSeconds} seconds.',
      );
    }

    for (var index = 1; index <= _maxScheduledReminders; index++) {
      final scheduledAt = scheduleAnchor.add(reminderInterval * index);
      final vibrateOnly =
          alwaysVibrateOnly || _isWithinQuietHoursAt(settings, scheduledAt);

      try {
        await _scheduleReminderNotification(
          id: _notificationIdBase + index,
          scheduledAt: scheduledAt,
          vibrateOnly: vibrateOnly,
          sound: settings.sound,
          scheduleMode: scheduleMode,
        );
      } catch (error) {
        // On Android 12+, exact alarms may be blocked by special app access.
        if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          if (kDebugMode) {
            debugPrint(
              'Exact alarm scheduling unavailable; falling back to inexact mode: $error',
            );
          }

          await _scheduleReminderNotification(
            id: _notificationIdBase + index,
            scheduledAt: scheduledAt,
            vibrateOnly: vibrateOnly,
            sound: settings.sound,
            scheduleMode: scheduleMode,
          );
        } else {
          rethrow;
        }
      }
    }

    if (kDebugMode) {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final scheduledCount =
          pending.where((request) => _isScheduledReminderId(request.id)).length;
      debugPrint(
        'Mindfulness Bell reminders scheduled: $scheduledCount at ${reminderInterval.inSeconds}s interval.',
      );
    }
  }

  static Future<void> restoreReminderIfEnabled() async {
    await initialize();

    final settingsService = MindfulnessBellSettingsService();
    final enabled = await settingsService.isReminderEnabled();
    if (!enabled) {
      return;
    }

    final pending = await _notificationsPlugin.pendingNotificationRequests();
    final alreadyScheduled =
        pending.any((request) => _isScheduledReminderId(request.id));

    if (alreadyScheduled) {
      return;
    }

    final settings = await settingsService.loadSettings();
    await startRecurringReminder(settings);

    if (kDebugMode) {
      debugPrint('Mindfulness Bell reminders restored on app launch.');
    }
  }

  static bool _isScheduledReminderId(int id) {
    return id > _notificationIdBase &&
        id <= (_notificationIdBase + _maxScheduledReminders);
  }

  static Future<void> _scheduleReminderNotification({
    required int id,
    required tz.TZDateTime scheduledAt,
    required bool vibrateOnly,
    required AlarmSound sound,
    required AndroidScheduleMode scheduleMode,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      'Mindfulness Bell',
      vibrateOnly
          ? 'Reminder triggered (vibrate only due to settings or mute conditions).'
          : 'Reminder triggered (${sound.label}).',
      scheduledAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          vibrateOnly
              ? _vibrateChannelId
              : (sound == AlarmSound.bell ? _audioChannelIdBell : _audioChannelIdBird),
          vibrateOnly
              ? 'Mindfulness Bell Vibrate Only'
              : (sound == AlarmSound.bell ? 'Mindfulness Bell (Bell)' : 'Mindfulness Bell (Bird)'),
          channelDescription: vibrateOnly
              ? 'Mindfulness reminders with vibration only'
              : 'Mindfulness reminders with sound and vibration',
          importance: Importance.high,
          priority: Priority.high,
          playSound: !vibrateOnly,
          sound: vibrateOnly
              ? null
              : RawResourceAndroidNotificationSound(sound == AlarmSound.bell ? 'bell_ringing' : 'forest_sound'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          ticker: 'Mindfulness Bell Reminder',
          visibility: NotificationVisibility.public,
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction('dismiss', 'Dismiss'),
          ],
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final canScheduleExact =
        await androidImplementation?.canScheduleExactNotifications();

    if (canScheduleExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> cancelRecurringReminder() async {
    await initialize();
    for (var index = 1; index <= _maxScheduledReminders; index++) {
      await _notificationsPlugin.cancel(_notificationIdBase + index);
    }
  }

  static Future<void> triggerAlarm(MindfulnessBellSettings settings) async {
    await initialize();

    final shouldMute = await DeviceAudioModeService.shouldMuteBell(settings);
    final isQuietHours = _isWithinQuietHours(settings);
    final vibrateOnly =
        shouldMute || isQuietHours || settings.sound == AlarmSound.vibrateOnly;

    final androidDetails = AndroidNotificationDetails(
      vibrateOnly
          ? _vibrateChannelId
          : (settings.sound == AlarmSound.bell ? _audioChannelIdBell : _audioChannelIdBird),
      vibrateOnly
          ? 'Mindfulness Bell Vibrate Only'
          : (settings.sound == AlarmSound.bell ? 'Mindfulness Bell (Bell)' : 'Mindfulness Bell (Bird)'),
      channelDescription: vibrateOnly
          ? 'Mindfulness reminders with vibration only'
          : 'Mindfulness reminders with sound and vibration',
      importance: Importance.high,
      priority: Priority.high,
      playSound: !vibrateOnly,
      sound: vibrateOnly
          ? null
          : RawResourceAndroidNotificationSound(settings.sound == AlarmSound.bell ? 'bell_ringing' : 'forest_sound'),
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      ticker: 'Mindfulness Bell Reminder',
      visibility: NotificationVisibility.public,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      _notificationIdBase,
      'Mindfulness Bell',
      vibrateOnly
          ? 'Reminder triggered (vibrate only due to settings or mute conditions).'
          : 'Reminder triggered (${settings.sound.label}).',
      details,
      payload: settings.sound.name,
    );

    if (!vibrateOnly) {
      await _playForegroundAudio(settings.sound);
    }
  }

  static bool _isWithinQuietHours(MindfulnessBellSettings settings) {
    return _isWithinQuietHoursAt(settings, DateTime.now());
  }

  static bool _isWithinQuietHoursAt(
    MindfulnessBellSettings settings,
    DateTime at,
  ) {
    if (!settings.quietHoursEnabled) {
      return false;
    }

    final currentMinutes = at.hour * 60 + at.minute;

    final start = settings.quietHoursStartMinutes;
    final end = settings.quietHoursEndMinutes;

    // Handle overnight ranges (e.g., 22:00 to 07:00)
    if (start > end) {
      return currentMinutes >= start || currentMinutes < end;
    }

    // Handle same-day ranges (e.g., 01:00 to 05:00)
    return currentMinutes >= start && currentMinutes < end;
  }

  static Future<void> _playForegroundAudio(AlarmSound sound) async {
    if (sound == AlarmSound.vibrateOnly) return;

    Source? source;

    if (sound == AlarmSound.bell) {
      // Small file — still bundled as asset
      source = AssetSource('sounds/bell-ringing-05.mp3');
    } else if (sound == AlarmSound.birdSong) {
      // Large file — stream from Firebase Storage / local cache
      try {
        final path = await AudioStreamingService()
            .getAudioPath('sounds/Forest_sound.mp3');
        if (path != null) {
          source = DeviceFileSource(path);
        } else {
          debugPrint('Forest sound not cached and download failed');
          return; // Notification itself is the fallback
        }
      } catch (e) {
        debugPrint('Error loading bird sound: $e');
        return;
      }
    }

    if (source == null) return;

    try {
      await _audioPlayer.stop(); // Stop any currently playing audio so it can replay
      await _audioPlayer.setVolume(0.9);
      await _audioPlayer.play(source);
      if (sound == AlarmSound.birdSong) {
        await Future.delayed(const Duration(seconds: 10));
        await _audioPlayer.stop();
      }
    } catch (_) {
      // Notification itself is the fallback trigger.
    }
  }
}
