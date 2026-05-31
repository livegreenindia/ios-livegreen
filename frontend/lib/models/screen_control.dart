import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'dart:async';
import 'dart:io';
import 'app_blocker.dart';
import 'usage_service.dart';
import 'monitor_apps.dart';

class ScreenTimeApp extends StatelessWidget {
  const ScreenTimeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF021F14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF388E3C),
          secondary: Color(0xFF388E3C),
          surface: Color(0xFF121212),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFE0E0E0),
          onBackground: Color(0xFFE0E0E0),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF021F14),
          foregroundColor: Color(0xFFE0E0E0),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF121212),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const PermissionWrapper(),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({Key? key}) : super(key: key);

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _checking = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) {
      setState(() { _checking = false; _hasPermissions = false; });
      return;
    }
    final accessibility = await AppBlocker.checkAccessibilityPermission();
    final usage = (await UsageStats.checkUsagePermission()) == true;

    setState(() {
      _checking = false;
      _hasPermissions = accessibility && usage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF021F14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF388E3C)),
        ),
      );
    }

    return _hasPermissions
        ? const SetLimitsScreen()
        : const PermissionsScreen();
  }
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({Key? key}) : super(key: key);

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _accessibilityEnabled = false;
  bool _usageEnabled = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!Platform.isAndroid) return;
    final a = await AppBlocker.checkAccessibilityPermission();
    final u = await UsageStats.checkUsagePermission();
    if (!mounted) return;
    final newAccessibility = a;
    final newUsage = u == true;

    if (newAccessibility == _accessibilityEnabled &&
        newUsage == _usageEnabled) {
      return;
    }

    setState(() {
      _accessibilityEnabled = newAccessibility;
      _usageEnabled = newUsage;
    });

    if (newAccessibility && newUsage) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _accessibilityEnabled && _usageEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFF021F14),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Permissions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enable permissions to let the app block apps by time and usage limits.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),

            _permissionCard(
              title: 'Accessibility (Blocking)',
              description: 'Required to detect foreground apps and block them.',
              enabled: _accessibilityEnabled,
              onEnable: () async {
                // Show prominent disclosure before requesting permission
                await _showAccessibilityDisclosure();
              },
            ),
            const SizedBox(height: 12),
            _permissionCard(
              title: 'Usage Access (Usage Tracking)',
              description: 'Required to read daily app usage time.',
              enabled: _usageEnabled,
              onEnable: () async {
                await UsageStats.grantUsagePermission();
              },
            ),
            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue
                    ? () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SetLimitsScreen(),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canContinue
                      ? const Color(0xFF388E3C)
                      : Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccessibilityDisclosure() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Accessibility Service Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LiveGreen uses Accessibility Services to help you maintain digital wellness:',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _disclosureItem(
                icon: Icons.block,
                title: 'App Blocking',
                description: 'Detect when you open distracting apps and automatically redirect you to the home screen during quiet hours or when usage limits are exceeded.',
              ),
              const SizedBox(height: 12),
              _disclosureItem(
                icon: Icons.schedule,
                title: 'Focus Time Protection',
                description: 'Prevent interruptions during your scheduled focus sessions and deep work periods.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip, color: Colors.orange[300], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Privacy: We only monitor app package names during quiet hours. No personal data, content, or keystrokes are collected or shared.',
                        style: TextStyle(color: Colors.orange[100], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You can disable this at any time in your device\'s Accessibility Settings.',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Decline',
              style: TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Accept', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppBlocker.requestAccessibilityPermission();
    }
  }

  Widget _disclosureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF388E3C), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _permissionCard({
    required String title,
    required String description,
    required bool enabled,
    required Future<void> Function() onEnable,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.error_outline,
            color: enabled ? Colors.greenAccent : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: enabled
                        ? null
                        : () async {
                            await onEnable();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: Text(enabled ? 'Enabled' : 'Enable'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppUsageData {
  final String packageName;
  final String appName;
  final IconData icon;
  final Color color;
  int timeLimitMinutes;

  AppUsageData({
    required this.packageName,
    required this.appName,
    required this.icon,
    required this.color,
    this.timeLimitMinutes = 15,
  });

  String get formattedLimit {
    if (timeLimitMinutes == 90) {
      return '90m (1.5h)';
    } else if (timeLimitMinutes == 120) {
      return '120m (2h)';
    } else {
      return '${timeLimitMinutes}m';
    }
  }
}

class SetLimitsScreen extends StatefulWidget {
  const SetLimitsScreen({Key? key}) : super(key: key);

  @override
  State<SetLimitsScreen> createState() => _SetLimitsScreenState();
}

class _SetLimitsScreenState extends State<SetLimitsScreen> {
  List<AppUsageData> _apps = [];
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 22, minute: 0);
  bool _hardLimitEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeApps();
    _loadSavedSettings();
    // Time blocking is enforced natively (Android) via quiet hours.
    // Flutter timer blocking is not used.
  }

  @override
  void dispose() {
    UsageService.instance.stop();
    super.dispose();
  }

  Future<void> _pushQuietHoursToAndroid() async {
    final morningMinutes = (_morningTime.hour * 60) + _morningTime.minute;
    final eveningMinutes = (_eveningTime.hour * 60) + _eveningTime.minute;
    await AppBlocker.updateQuietHours(
      morningMinutes: morningMinutes,
      eveningMinutes: eveningMinutes,
    );
  }

  void _initializeApps() {
    _apps = monitoredApps
        .map(
          (app) => AppUsageData(
            packageName: app.packageName,
            appName: app.name,
            icon: app.icon,
            color: app.color,
            timeLimitMinutes: app.packageName == 'com.whatsapp' ? 30 : 15,
          ),
        )
        .toList();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (var app in _apps) {
        app.timeLimitMinutes =
            prefs.getInt('limit_${app.packageName}') ?? app.timeLimitMinutes;
      }

      final morningHour = prefs.getInt('morning_hour') ?? 7;
      final morningMinute = prefs.getInt('morning_minute') ?? 0;
      _morningTime = TimeOfDay(hour: morningHour, minute: morningMinute);

      final eveningHour = prefs.getInt('evening_hour') ?? 22;
      final eveningMinute = prefs.getInt('evening_minute') ?? 0;
      _eveningTime = TimeOfDay(hour: eveningHour, minute: eveningMinute);

      _hardLimitEnabled = prefs.getBool('hard_limit_enabled') ?? false;
    });

    await _pushQuietHoursToAndroid();

    // Start syncing only after settings are loaded, otherwise Android may receive stale values.
    UsageService.instance.start();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    for (var app in _apps) {
      await prefs.setInt('limit_${app.packageName}', app.timeLimitMinutes);
    }

    await prefs.setInt('morning_hour', _morningTime.hour);
    await prefs.setInt('morning_minute', _morningTime.minute);
    await prefs.setInt('evening_hour', _eveningTime.hour);
    await prefs.setInt('evening_minute', _eveningTime.minute);
    await prefs.setBool('hard_limit_enabled', _hardLimitEnabled);

    // Push updated settings to Android immediately
    await UsageService.instance.syncImmediate();
  }

  Future<void> _saveLimit(String packageName, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('limit_$packageName', minutes);
  }

  Future<void> _saveMorningTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('morning_hour', time.hour);
    await prefs.setInt('morning_minute', time.minute);

    await _pushQuietHoursToAndroid();
  }

  Future<void> _saveEveningTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('evening_hour', time.hour);
    await prefs.setInt('evening_minute', time.minute);

    await _pushQuietHoursToAndroid();
  }

  Future<void> _saveHardLimitEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hard_limit_enabled', enabled);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021F14),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Set Limits',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            // TODO: Later change this to go back one page instead of closing
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close, color: Colors.white, size: 16),
          tooltip: 'Close',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),

            _buildSectionTitle('App Limits'),
            const SizedBox(height: 4),
            ..._apps.map((app) => _buildAppLimitSlider(app)).toList(),

            const SizedBox(height: 6),

            _buildSectionTitle('Time Blocks'),
            const SizedBox(height: 4),
            _buildTimeBlockCard(
              'Morning Start',
              'Allow apps from this time',
              _morningTime,
              (time) {
                setState(() => _morningTime = time);
                _saveMorningTime(time);
              },
            ),
            _buildTimeBlockCard(
              'Evening End',
              'Allow apps until this time',
              _eveningTime,
              (time) {
                setState(() => _eveningTime = time);
                _saveEveningTime(time);
              },
            ),

            const SizedBox(height: 8),

            _buildSectionTitle('Hard Limit'),
            const SizedBox(height: 4),
            _buildHardLimitCard(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _saveSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings saved'),
                      backgroundColor: Color(0xFF388E3C),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF388E3C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    for (var app in _apps) {
                      app.timeLimitMinutes = app.packageName == 'com.whatsapp'
                          ? 30
                          : 15;
                    }
                    _morningTime = const TimeOfDay(hour: 7, minute: 0);
                    _eveningTime = const TimeOfDay(hour: 22, minute: 0);
                    _hardLimitEnabled = false;
                  });
                  _saveSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All limits reset to default'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete Limit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildAppLimitSlider(AppUsageData app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(app.icon, color: app.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              app.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            app.formattedLimit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: app.color,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: app.color,
                overlayColor: app.color.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
              ),
              child: Slider(
                value: app.timeLimitMinutes.toDouble().clamp(15.0, 120.0),
                min: 15,
                max: 120,
                divisions: 5,
                onChanged: (value) {
                  setState(() {
                    // Map the slider value to exact steps
                    final steps = [15, 30, 45, 60, 90, 120];
                    final index = ((value - 15) / 21).round().clamp(0, 5);
                    app.timeLimitMinutes = steps[index];
                  });
                  _saveLimit(app.packageName, app.timeLimitMinutes);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlockCard(
    String title,
    String description,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: time,
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF388E3C),
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                onTimeChanged(picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTime(time),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardLimitCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Block apps when limit is reached',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Apps will be completely blocked when daily limit is reached',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: _hardLimitEnabled,
            onChanged: (value) async {
              setState(() => _hardLimitEnabled = value);
              await _saveHardLimitEnabled(value);

              // Push updated limits immediately, then restart periodic sync.
              await UsageService.instance.syncImmediate();
              UsageService.instance.start();
            },
            activeColor: const Color(0xFF388E3C),
            activeTrackColor: Colors.white.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.5),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}
