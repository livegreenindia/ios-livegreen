import 'dart:async';
import 'package:flutter/services.dart';

class DigitalWellbeingService {
  static const MethodChannel _channel = MethodChannel('livegreen/digital_wellbeing');

  /// Returns whether the app has Usage Access permission
  static Future<bool> isPermissionGranted() async {
    try {
      final res = await _channel.invokeMethod('isPermissionGranted');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Open the system settings screen where the user can grant Usage Access
  static Future<void> openPermissionSettings() async {
    await _channel.invokeMethod('openPermissionSettings');
  }

  /// Get aggregated usage summary for a range: 'daily','weekly','monthly','yearly'
  /// Returns a map { 'minutes': double, 'apps': List<Map> }
  static Future<Map<String, dynamic>?> getUsageSummary(String range) async {
    try {
      final res = await _channel.invokeMethod('getUsageSummary', {'range': range});
  if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Get detailed app usage breakdown for social media apps
  /// Returns a map { 'apps': List<Map<String, dynamic>> } where each app has:
  /// { 'packageName': String, 'appName': String, 'minutes': double, 'icon': Uint8List }
  static Future<Map<String, dynamic>?> getSocialMediaUsage(String range) async {
    try {
      final res = await _channel.invokeMethod('getSocialMediaUsage', {'range': range});
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Returns app ops state for GET_USAGE_STATS: { 'mode': int, 'label': string }
  static Future<Map<String, dynamic>?> appOpsState() async {
    try {
      final res = await _channel.invokeMethod('appOpsState');
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } on PlatformException {
      return null;
    }
  }
}
