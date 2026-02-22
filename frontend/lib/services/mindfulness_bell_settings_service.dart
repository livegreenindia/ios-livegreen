import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mindfulness_bell_settings.dart';

class MindfulnessBellSettingsService {
  static const _settingsKey = 'mindfulness_bell_settings_v1';
  static const _enabledKey = 'mindfulness_bell_enabled_v1';

  Future<MindfulnessBellSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return MindfulnessBellSettings.defaults;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MindfulnessBellSettings.fromMap(map);
    } catch (_) {
      return MindfulnessBellSettings.defaults;
    }
  }

  Future<void> saveSettings(MindfulnessBellSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toMap()));
  }

  Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
}
