import 'package:flutter/services.dart';

import '../models/mindfulness_bell_settings.dart';

class DeviceAudioModeService {
  static const MethodChannel _channel =
      MethodChannel('com.livegreen.app/device_state');

  static Future<bool> isSilentModeEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSilentModeEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDoNotDisturbEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDoNotDisturbEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAirplaneModeEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAirplaneModeEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shouldMuteBell(MindfulnessBellSettings settings) async {
    final checks = await Future.wait([
      settings.muteWhenSilentMode
          ? isSilentModeEnabled()
          : Future<bool>.value(false),
      settings.muteWhenDoNotDisturb
          ? isDoNotDisturbEnabled()
          : Future<bool>.value(false),
      settings.muteWhenFlightMode
          ? isAirplaneModeEnabled()
          : Future<bool>.value(false),
    ]);

    return checks.any((value) => value);
  }
}
