import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

import 'app_blocker.dart';
import 'monitor_apps.dart';

class UsageService {
  static UsageService? _instance;
  UsageService._();
  static UsageService get instance => _instance ??= UsageService._();

  Timer? _timer;

  void start() {
    _timer?.cancel();
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sync();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> syncImmediate() async {
    await _sync();
  }

  Future<void> _sync() async {
    try {
      final hasUsagePermission =
          (await UsageStats.checkUsagePermission()) == true;
      if (!hasUsagePermission) return;

      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final stats = await UsageStats.queryUsageStats(startOfDay, now);

      final trackedPkgs = monitoredPackageNames();

      final minutesByPkg = <String, int>{};
      for (final info in stats) {
        final pkg = info.packageName;
        if (pkg == null || !trackedPkgs.contains(pkg)) continue;
        final ms = int.tryParse(info.totalTimeInForeground ?? '0') ?? 0;
        minutesByPkg[pkg] = (ms / 60000).floor();
      }

      // Push usage to Android
      for (final entry in minutesByPkg.entries) {
        await AppBlocker.updateUsage(entry.key, entry.value);
      }

      // Push limits to Android (only if hard limit enabled)
      final hard = prefs.getBool('hard_limit_enabled') ?? false;
      final limits = <String, int>{};
      if (hard) {
        for (final pkg in trackedPkgs) {
          final limit = prefs.getInt('limit_$pkg') ?? 60;
          limits[pkg] = limit;
        }
      }
      if (kDebugMode) {
        debugPrint(
          'UsageService: hard_limit_enabled=$hard, pushing limits=$limits',
        );
      }
      await AppBlocker.updateLimits(limits);
    } catch (e) {
      // ignore: avoid_print
      print('UsageService sync error: $e');
    }
  }
}
