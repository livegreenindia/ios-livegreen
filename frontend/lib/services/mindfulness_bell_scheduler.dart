import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/mindfulness_bell_settings.dart';
import 'audio_streaming_service.dart';
import 'device_audio_mode_service.dart';

class MindfulnessBellScheduler {
  static const String _audioChannelId = 'mindfulness_bell_audio';
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

    await androidImplementation?.requestNotificationsPermission();

    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _audioChannelId,
        'Mindfulness Bell Audio',
        description: 'Mindfulness reminders with sound and vibration',
        importance: Importance.high,
        playSound: true,
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

    _notificationsInitialized = true;
  }

  static Future<void> startRecurringReminder(
    MindfulnessBellSettings settings,
  ) async {
    await initialize();
    await cancelRecurringReminder();

    final shouldMute = await DeviceAudioModeService.shouldMuteBell(settings);
    final vibrateOnly = shouldMute || settings.sound == AlarmSound.vibrateOnly;

    for (var index = 1; index <= _maxScheduledReminders; index++) {
      final scheduledAt = tz.TZDateTime.now(
        tz.local,
      ).add(settings.interval.duration * index);

      await _notificationsPlugin.zonedSchedule(
        _notificationIdBase + index,
        'Mindfulness Bell',
        vibrateOnly
            ? 'Reminder triggered (vibrate only due to settings or mute conditions).'
            : 'Reminder triggered (${settings.sound.label}).',
        scheduledAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            vibrateOnly ? _vibrateChannelId : _audioChannelId,
            vibrateOnly
                ? 'Mindfulness Bell Vibrate Only'
                : 'Mindfulness Bell Audio',
            channelDescription: vibrateOnly
                ? 'Mindfulness reminders with vibration only'
                : 'Mindfulness reminders with sound and vibration',
            importance: Importance.high,
            priority: Priority.high,
            playSound: !vibrateOnly,
            enableVibration: true,
            category: AndroidNotificationCategory.reminder,
            ticker: 'Mindfulness Bell Reminder',
            visibility: NotificationVisibility.public,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss', 'Dismiss'),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
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
      vibrateOnly ? _vibrateChannelId : _audioChannelId,
      vibrateOnly ? 'Mindfulness Bell Vibrate Only' : 'Mindfulness Bell Audio',
      channelDescription: vibrateOnly
          ? 'Mindfulness reminders with vibration only'
          : 'Mindfulness reminders with sound and vibration',
      importance: Importance.high,
      priority: Priority.high,
      playSound: !vibrateOnly,
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
    if (!settings.quietHoursEnabled) {
      return false;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

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
        final path =
            await AudioStreamingService().getAudioPath('sounds/Forest_sound.mp3');
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
