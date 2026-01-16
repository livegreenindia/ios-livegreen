import 'package:flutter/services.dart';

class AppBlocker {
  static const _channel = MethodChannel('com.example.app_name/blocker');

  static Future<bool> checkAccessibilityPermission() async {
    try {
      final result = await _channel.invokeMethod(
        'checkAccessibilityPermission',
      );
      return result == true;
    } on PlatformException catch (e) {
      print("Error checking accessibility: ${e.message}");
      return false;
    }
  }

  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } on PlatformException catch (e) {
      print("Error enabling blocking: ${e.message}");
    }
  }

  static Future<void> blockApp(String packageName) async {
    try {
      await _channel.invokeMethod('blockApp', {'package': packageName});
    } on PlatformException catch (e) {
      print("Error blocking app: ${e.message}");
    }
  }

  static Future<void> unblockApp(String packageName) async {
    try {
      await _channel.invokeMethod('unblockApp', {'package': packageName});
    } on PlatformException catch (e) {
      print("Error unblocking app: ${e.message}");
    }
  }

  static Future<void> updateLimits(Map<String, int> limits) async {
    try {
      await _channel.invokeMethod('updateLimits', limits);
    } on PlatformException catch (e) {
      print("Error updating limits: ${e.message}");
    }
  }

  static Future<void> updateUsage(String packageName, int minutes) async {
    try {
      await _channel.invokeMethod('updateUsage', {
        'package': packageName,
        'minutes': minutes,
      });
    } on PlatformException catch (e) {
      print("Error updating usage: ${e.message}");
    }
  }

  static Future<void> updateQuietHours({
    required int morningMinutes,
    required int eveningMinutes,
  }) async {
    try {
      await _channel.invokeMethod('updateQuietHours', {
        'morning': morningMinutes,
        'evening': eveningMinutes,
      });
    } on PlatformException catch (e) {
      print("Error updating quiet hours: ${e.message}");
    }
  }
}
