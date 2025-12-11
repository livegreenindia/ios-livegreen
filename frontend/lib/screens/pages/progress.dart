// ignore_for_file: deprecated_member_use, duplicate_ignore, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/api.dart';
import '../../config/api.dart' as cfg;
import '../../theme/app_theme.dart';
import 'progress_refresh_notifier.dart';
import '../../services/digital_wellbeing_service.dart';
import '../../services/wearable_integration_service.dart';
import '../../services/progress_calculator_service.dart';
import '../integration_progress_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
// package_info and Clipboard imports removed (diagnostic UI removed)

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Theme-aware color getters
  Color get primaryColor => AppColors.primary;
  Color get primaryLight => AppColors.primaryLight;
  Color get backgroundLight => AppColors.backgroundLight;
  Color get backgroundDark => AppColors.backgroundDark;
  Color get secondaryColor => AppColors.secondary;
  Color get successColor => AppColors.success;
  Color get warningColor => AppColors.warning;
  Color get errorColor => AppColors.error;
  
  // Chart animation
  double _chartAnimationValue = 0.0;

  String _range = 'daily'; // Default to daily view for Digital Wellbeing
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _series = [];
  // Removed _screenMinutes - no longer showing total screen time
  bool _usagePermission = false;
  List<Map<String, dynamic>> _socialMediaApps = []; // Social media usage breakdown
  Map<String, dynamic>? _fitbitData;
  Map<String, dynamic>? _samsungData;
  // Aggregated summaries computed from Firestore historical `daily_metrics`
  Map<String, dynamic>? _fitbitSummary;
  Map<String, dynamic>? _samsungSummary;
  final WearableIntegrationService _wearableService = WearableIntegrationService();
  StreamSubscription<Map<String, dynamic>>? _wearableStreamSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _dailyMetricsSub;
  StreamSubscription<User?>? _authStateSub;
  
  // Activity-based progress tracking
  int _todayCompletedCount = 0;
  int _todayExpectedCount = 0;
  int _todayCompletionPercent = 0;
  StreamSubscription<Map<String, dynamic>>? _progressSub;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
  WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _fetchSeries();
    _initUsage();
    _loadActivityProgress();
    _listenToActivityProgress();
    // Animate chart bars
    _animateChart();
    // Register for wearable data updates so previews can be shown inline
    _wearableService.registerDataCallback((fitbit, samsung) {
      if (!mounted) return;
      setState(() {
        if (fitbit.isNotEmpty) _fitbitData = fitbit;
        if (samsung.isNotEmpty) _samsungData = samsung;
      });
    });

    // Listen to shared live stream (singleton) for in-progress previews
    try {
      _wearableStreamSub = _wearableService.dataStream.listen((map) {
        if (!mounted) return;
        setState(() {
          final fit = map['fitbit'] as Map<String, dynamic>? ?? {};
          final sam = map['samsung'] as Map<String, dynamic>? ?? {};
          if (fit.isNotEmpty) _fitbitData = fit;
          if (sam.isNotEmpty) _samsungData = sam;
        });
      });
    } catch (_) {}

    // Listen to Firestore for the most recent daily_metrics for the signed-in user
    _listenToLatestDailyMetrics();
    // Load aggregated wearable metrics for the selected range
    _loadWearableAggregates();
    _animationController.forward();
  }

  /// Load today's activity progress
  Future<void> _loadActivityProgress() async {
    try {
      final progress = await ProgressCalculatorService.getTodaysProgress();
      if (mounted) {
        setState(() {
          _todayCompletedCount = progress['completedCount'] ?? 0;
          _todayExpectedCount = progress['expectedCount'] ?? 0;
          _todayCompletionPercent = progress['completionPercent'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading activity progress: $e');
    }
  }

  /// Listen to real-time activity progress updates
  void _listenToActivityProgress() {
    _progressSub = ProgressCalculatorService.progressStream().listen((progress) {
      if (mounted) {
        setState(() {
          _todayCompletedCount = progress['completedCount'] ?? 0;
          _todayExpectedCount = progress['expectedCount'] ?? 0;
          _todayCompletionPercent = progress['completionPercent'] ?? 0;
        });
      }
    });
  }
  
  /// Animate chart bars with staggered effect
  Future<void> _animateChart() async {
    setState(() => _chartAnimationValue = 0.0);
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 8));
      if (mounted) {
        setState(() => _chartAnimationValue = i / 100);
      }
    }
  }
  
  /// Generate smart insights based on data
  List<Map<String, dynamic>> _generateInsights(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];
    
    final insights = <Map<String, dynamic>>[];
    
    // Calculate averages and trends
    double avgCompletion = 0;
    double avgHappiness = 0;
    int aboveGoal = 0;
    double trend = 0;
    
    for (int i = 0; i < data.length; i++) {
      final comp = ((data[i]['completionPercent'] ?? 0) as num).toDouble();
      final hap = ((data[i]['happiness'] ?? 0) as num).toDouble();
      avgCompletion += comp;
      avgHappiness += hap;
      if (comp >= 80) aboveGoal++;
      
      // Calculate trend (compare first half vs second half)
      if (data.length >= 4) {
        final mid = data.length ~/ 2;
        if (i < mid) trend -= comp / mid;
        else trend += comp / (data.length - mid);
      }
    }
    
    avgCompletion /= data.length;
    avgHappiness /= data.length;
    
    // Insight 1: Performance summary
    if (avgCompletion >= 80) {
      insights.add({
        'icon': '🌟',
        'title': 'Outstanding Performance!',
        'description': 'Your average green score is ${avgCompletion.toStringAsFixed(0)}%. Keep up the excellent eco-habits!',
        'color': AppColors.success,
      });
    } else if (avgCompletion >= 60) {
      insights.add({
        'icon': '💪',
        'title': 'Great Progress',
        'description': 'You\'re averaging ${avgCompletion.toStringAsFixed(0)}%. Just ${(80 - avgCompletion).toStringAsFixed(0)}% away from your goal!',
        'color': AppColors.info,
      });
    } else {
      insights.add({
        'icon': '🌱',
        'title': 'Room to Grow',
        'description': 'Your average is ${avgCompletion.toStringAsFixed(0)}%. Small daily changes lead to big impact!',
        'color': AppColors.warning,
      });
    }
    
    // Insight 2: Trend analysis
    if (trend > 10) {
      insights.add({
        'icon': '📈',
        'title': 'Trending Up!',
        'description': 'Your eco-scores are improving! Recent performance is stronger than earlier.',
        'color': AppColors.primaryLight,
      });
    } else if (trend < -10) {
      insights.add({
        'icon': '📉',
        'title': 'Attention Needed',
        'description': 'Recent scores are lower. Try setting reminders to stay on track.',
        'color': AppColors.error,
      });
    }
    
    // Insight 3: Goal achievement
    if (aboveGoal > 0) {
      final percentage = ((aboveGoal / data.length) * 100).toStringAsFixed(0);
      insights.add({
        'icon': '🎯',
        'title': 'Goal Achievement',
        'description': 'You hit your 80% goal on $aboveGoal ${aboveGoal == 1 ? 'day' : 'days'} ($percentage% of the time).',
        'color': AppColors.secondary,
      });
    }
    
    // Insight 4: Wellness correlation
    if (avgHappiness >= 7) {
      insights.add({
        'icon': '💚',
        'title': 'Wellness Boost',
        'description': 'Your eco-actions correlate with ${avgHappiness.toStringAsFixed(1)}/10 wellness. Nature is healing!',
        'color': AppColors.secondaryLight,
      });
    }
    
    return insights;
  }
  
  /// Build smart insights widget
  Widget _buildSmartInsights(List<Map<String, dynamic>> data) {
    final insights = _generateInsights(data);
    if (insights.isEmpty) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedOpacity(
      opacity: _chartAnimationValue,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9C27B0).withOpacity(0.2),
                        const Color(0xFF673AB7).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Smart Insights',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.take(3).map((insight) => _buildInsightTile(insight, isDark)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInsightTile(Map<String, dynamic> insight, bool isDark) {
    final color = insight['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(insight['icon'] as String, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight['title'] as String,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight['description'] as String,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // package info loader removed (not needed after removing diagnostic UI)

  @override
  void dispose() {
    // cancel any ongoing wearable operations
    try {
      _wearableService.cancel();
    } catch (_) {}
    try {
      _wearableStreamSub?.cancel();
    } catch (_) {}
    try {
      _dailyMetricsSub?.cancel();
    } catch (_) {}
    try {
      _authStateSub?.cancel();
    } catch (_) {}
    try {
      _progressSub?.cancel();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Small delay to allow system to update permission state after returning from settings
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _initUsage();
      });
    }
  }


  Future<void> _initUsage() async {
    try {
      final granted = await DigitalWellbeingService.isPermissionGranted();
      setState(() {
        _usagePermission = granted;
      });
      if (granted) await _fetchUsage();
    } catch (_) {}
  }

  Future<void> _fetchUsage() async {
    try {
      if (kDebugMode) {
        debugPrint('[DigitalWellbeing] Fetching social media usage for range: $_range');
      }
      
      // Fetch social media usage breakdown
      final socialMap = await DigitalWellbeingService.getSocialMediaUsage(
        _range == 'daily' ? 'daily' : 
        _range == 'weekly' ? 'weekly' : 
        _range == 'monthly' ? 'monthly' : 'yearly'
      );
      
      if (kDebugMode) {
        debugPrint('[DigitalWellbeing] Received data: ${socialMap != null ? "YES" : "NULL"}');
        if (socialMap != null) {
          debugPrint('[DigitalWellbeing] Apps in response: ${socialMap['apps']}');
        }
      }
      
      if (socialMap != null && mounted) {
        if (socialMap['apps'] != null && socialMap['apps'] is List) {
          // Properly convert the nested maps from Object? to String, dynamic
          final rawApps = socialMap['apps'] as List;
          final apps = rawApps.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).where((app) => app.isNotEmpty).toList();
          
          if (kDebugMode) {
            debugPrint('[DigitalWellbeing] Social media apps received: ${apps.length}');
            for (var app in apps) {
              debugPrint('[DigitalWellbeing] App: ${app['appName']}, Minutes: ${app['minutes']}');
            }
          }
          
          setState(() {
            _socialMediaApps = apps;
          });
          
          // Save daily social media usage to Firestore for notification checking
          if (_range == 'daily' && apps.isNotEmpty) {
            _saveSocialMediaMetrics(apps);
          }
        } else {
          if (kDebugMode) {
            debugPrint('[DigitalWellbeing] No apps array in response');
          }
          setState(() {
            _socialMediaApps = [];
          });
        }
      } else {
        if (kDebugMode) {
          debugPrint('[DigitalWellbeing] socialMap is null or widget unmounted');
        }
        if (mounted) {
          setState(() {
            _socialMediaApps = [];
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DigitalWellbeing] Error fetching usage: $e');
      }
      if (mounted) {
        setState(() {
          _socialMediaApps = [];
        });
      }
    }
  }
  
  /// Save social media usage to Firestore for notification alerts
  Future<void> _saveSocialMediaMetrics(List<Map<String, dynamic>> apps) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      int youtubeMinutes = 0;
      int instagramMinutes = 0;
      
      int totalSocialMinutes = 0;
      for (var app in apps) {
        final name = (app['appName'] ?? '').toString().toLowerCase();
        final minutes = (app['minutes'] as num?)?.toInt() ?? 0;
        totalSocialMinutes += minutes; // apps list already filtered to social media
        if (name.contains('youtube')) {
          youtubeMinutes += minutes;
        } else if (name.contains('instagram')) {
          instagramMinutes += minutes;
        }
      }
      
      // Save to daily_metrics collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_metrics')
          .doc(today)
          .set({
        'date': today,
        'socialMediaMinutes': totalSocialMinutes,
        'youtubeMinutes': youtubeMinutes,
        'instagramMinutes': instagramMinutes,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      // Silently fail - metrics are optional
      if (kDebugMode) {
        debugPrint('Failed to save social media metrics: $e');
      }
    }
  }

  void _listenToLatestDailyMetrics() {
    try {
      // Cancel any existing listener first
      try {
        _dailyMetricsSub?.cancel();
      } catch (_) {}

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Wait for a sign-in event and then attach the listener once
        try {
          _authStateSub?.cancel();
        } catch (_) {}
        _authStateSub = FirebaseAuth.instance.authStateChanges().listen((u) {
          if (u != null) {
            // user signed in — attach Firestore listener
            _authStateSub?.cancel();
            _attachDailyMetricsListener(u.uid);
          }
        });
        return;
      }
      _attachDailyMetricsListener(user.uid);
    } catch (_) {}
  }

  void _attachDailyMetricsListener(String uid) {
    try {
      _dailyMetricsSub = FirebaseFirestore.instance
          .collection('daily_metrics')
          .where('uid', isEqualTo: uid)
          .orderBy('last_updated', descending: true)
          .limit(1)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        if (snap.docs.isEmpty) return;
        final doc = snap.docs.first.data();
        setState(() {
          final fit = doc['fitbit'] as Map<String, dynamic>?;
          final sam = doc['samsung'] as Map<String, dynamic>?;
          if (fit != null && fit.isNotEmpty) _fitbitData = Map<String, dynamic>.from(fit);
          if (sam != null && sam.isNotEmpty) _samsungData = Map<String, dynamic>.from(sam);
        });
      }, onError: (e) {
        // Surface permission or other Firestore errors to UI (and optionally Notify user)
        if (!mounted) return;
        try {
          final msg = e is FirebaseException ? '${e.code}: ${e.message}' : e.toString();
          setState(() { _error = 'Firestore error: $msg'; });
          // Show a non-intrusive snackbar for visibility during development
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firestore error: $msg')));
        } catch (_) {}
      });
    } catch (e) {
      // guard: in case attaching the listener throws synchronously
      if (!mounted) return;
      try {
        setState(() { _error = e.toString(); });
      } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = Provider.of<ProgressRefreshNotifier>(context);
    if (notifier.shouldRefresh) {
      _fetchSeries();
      _loadActivityProgress(); // Refresh activity progress too
      notifier.consumeRefresh();
    }
  }

  Future<void> _fetchSeries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ApiService(baseUrl: cfg.apiBaseUrl);
    try {
      final rangeMap = {'daily': 'day', 'weekly': 'week', 'monthly': 'month', 'yearly': 'year'};
      final response = await api.getProgressSeries(rangeMap[_range] ?? 'day');

      setState(() {
        _series = response;
        _loading = false;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _avgHappiness() {
    final vals = _series.map((e) => (e['happiness'] ?? 0) as num).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  double _avgCompletion() {
    final vals = _series.map((e) => (e['completionPercent'] ?? 0) as num).toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  String _changeText() {
    if (_series.length < 2) return "";
    final first = _series.first;
    final last = _series.last;
    final hapChange =
        ((last['happiness'] ?? 0) as num) - ((first['happiness'] ?? 0) as num);
    final compChange = ((last['completionPercent'] ?? 0) as num) -
        ((first['completionPercent'] ?? 0) as num);
    return "${hapChange >= 0 ? '+' : ''}${hapChange.toStringAsFixed(1)} happiness, "
        "${compChange >= 0 ? '+' : ''}${compChange.toStringAsFixed(0)}% completion";
  }

  bool _isPositiveChange() {
    if (_series.length < 2) return true;
    final first = _series.first;
    final last = _series.last;
    final hapChange = ((last['happiness'] ?? 0) as num) - ((first['happiness'] ?? 0) as num);
    return hapChange >= 0;
  }

  List<Map<String, dynamic>> _aggregateForRange(List<Map<String, dynamic>> raw, String range) {
    // For daily view, just return today's data or empty
    if (range == 'daily') {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return raw.where((e) => e['date']?.toString() == today).toList();
    }
    
    if (range == 'weekly') return raw;

    final byDate = <String, Map<String, dynamic>>{};
    for (final e in raw) {
      final d = e['date']?.toString();
      if (d != null) byDate[d] = e;
    }

    if (range == 'monthly') {
      if (raw.isEmpty) return raw;
      final dateMap = <String, Map<String, dynamic>>{};
      for (final e in raw) {
        final d = e['date']?.toString();
        if (d != null) dateMap[d] = e;
      }

  final now = DateTime.now();
  DateTime startDate = DateTime(now.year, now.month, 1);
  DateTime endDate = DateTime(now.year, now.month + 1, 0);

      startDate = startDate.subtract(Duration(days: (startDate.weekday + 6) % 7));
      endDate = endDate.add(Duration(days: 7 - endDate.weekday));

      final buckets = <Map<String, dynamic>>[];
      DateTime cur = startDate;
  // weekIndex no longer required; labels use date ranges
      while (cur.isBefore(endDate) || cur.isAtSameMomentAs(endDate)) {
        final weekStart = cur;
        final weekEnd = cur.add(const Duration(days: 6));
        final days = <Map<String, dynamic>>[];
        for (int i = 0; i < 7; i++) {
          final d = weekStart.add(Duration(days: i));
          // only include days that belong to the target month (avoid next/prev-month spillover)
          if (d.month != now.month) continue;
          final key = d.toIso8601String().substring(0,10);
          if (dateMap.containsKey(key)) {
            final entry = Map<String, dynamic>.from(dateMap[key]!);
            entry['date'] = key;
            days.add(entry);
          }
        }
        double avgHap = 0.0;
        double avgComp = 0.0;
        int count = 0;
        if (days.isNotEmpty) {
          final totalHap = days.map((x) => ((x['happiness'] ?? 0) as num).toDouble()).fold(0.0, (double a, double b) => a + b);
          final totalComp = days.map((x) => ((x['completionPercent'] ?? 0) as num).toDouble()).fold(0.0, (double a, double b) => a + b);
          avgHap = totalHap / days.length;
          avgComp = totalComp / days.length;
          count = days.map((x) => (x['count'] ?? 0) as int).fold(0, (a, b) => a + b);
        }
  // Build a friendly label clipped to the current month, e.g. "1–7 Oct"
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);
  final displayStart = weekStart.isBefore(monthStart) ? monthStart : weekStart;
  final displayEnd = weekEnd.isAfter(monthEnd) ? monthEnd : weekEnd;
  final monthLabel = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month - 1];
  final label = '${displayStart.day}–${displayEnd.day} $monthLabel';
  buckets.add({'label': label, 'happiness': avgHap, 'completionPercent': avgComp, 'count': count, 'items': days, 'weekStart': weekStart.toIso8601String().substring(0,10), 'weekEnd': weekEnd.toIso8601String().substring(0,10)});
        cur = cur.add(const Duration(days: 7));
      }
      return buckets;
    }

    if (range == 'yearly') {
      final now = DateTime.now();
      final months = List.generate(12, (i) => <Map<String, dynamic>>[]);
      for (final e in raw) {
        final d = e['date']?.toString();
        if (d == null) continue;
        try {
          final dt = DateTime.parse(d);
          final idx = dt.month - 1;
          months[idx].add(e);
        } catch (_) {}
      }
      final labels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final res = <Map<String, dynamic>>[];
      // Only include months up to the current month to avoid showing future months (e.g., Nov when it's Oct)
      final lastMonthIndex = now.month - 1;
      for (int m = 0; m <= lastMonthIndex; m++) {
        final slice = months[m];
        if (slice.isEmpty) {
          res.add({'label': labels[m], 'happiness': 0, 'completionPercent': 0, 'count': 0, 'items': []});
          continue;
        }
        final totalHap = slice.map((x) => ((x['happiness'] ?? 0) as num).toDouble()).fold(0.0, (double a, double b) => a + b);
        final totalComp = slice.map((x) => ((x['completionPercent'] ?? 0) as num).toDouble()).fold(0.0, (double a, double b) => a + b);
        final avgHap = totalHap / slice.length;
        final avgComp = totalComp / slice.length;
        final count = slice.map((x) => (x['count'] ?? 0) as int).fold(0, (a, b) => a + b);
        res.add({'label': labels[m], 'happiness': avgHap, 'completionPercent': avgComp, 'count': count, 'items': slice.map((e) { final d = e['date']?.toString() ?? ''; return {...e, 'date': d}; }).toList()});
      }
      return res;
    }

    return raw;
  }

  Widget _buildCharts() {
    if (_series.isEmpty) return _placeholderChart("No data yet");
    final display = _aggregateForRange(_series, _range);
    
    // Guard against empty display data after aggregation
    if (display.isEmpty) return _placeholderChart("No data for selected range");
    
    // For daily view with single data point, show a simplified circular progress instead
    if (_range == 'daily' && display.length == 1) {
      return _buildDailyProgressView(display.first);
    }

    final happinessSpots = <FlSpot>[];
    final completionBars = <BarChartGroupData>[];

    for (int i = 0; i < display.length; i++) {
      final e = display[i];
      final hap = ((e['happiness'] ?? 0) as num).toDouble();
      final comp = ((e['completionPercent'] ?? 0) as num).toDouble();
      
      // Staggered animation - each bar animates slightly after previous
      final staggerDelay = i / display.length;
      final adjustedAnimation = (_chartAnimationValue - staggerDelay * 0.3).clamp(0.0, 1.0) / 0.7;
      final animatedComp = comp * adjustedAnimation.clamp(0.0, 1.0);

      happinessSpots.add(FlSpot(i.toDouble(), (hap * 10.0) * _chartAnimationValue));
      
      // Dynamic color based on completion percentage with brand colors
      Color barColor = primaryColor;
      Color barColorLight = primaryLight.withOpacity(0.6);
      if (comp >= 80) {
        barColor = successColor; // Green for excellent
        barColorLight = successColor.withOpacity(0.6);
      } else if (comp >= 50) {
        barColor = primaryColor; // Primary green for good  
        barColorLight = primaryLight.withOpacity(0.6);
      } else if (comp >= 25) {
        barColor = warningColor; // Orange for moderate
        barColorLight = warningColor.withOpacity(0.6);
      } else {
        barColor = errorColor; // Red for low
        barColorLight = errorColor.withOpacity(0.6);
      }
      
      completionBars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: animatedComp,
              width: _range == 'yearly' ? 18 : _range == 'monthly' ? 22 : 28,
              color: barColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              gradient: LinearGradient(
                colors: [barColorLight, barColor],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 1.0],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100,
                color: Colors.grey.withOpacity(0.08),
              ),
            ),
          ],
          showingTooltipIndicators: [],
        ),
      );
    }

    // Calculate average for achievement badge
    double avgCompletion = 0;
    for (final e in display) {
      avgCompletion += ((e['completionPercent'] ?? 0) as num).toDouble();
    }
    avgCompletion /= display.length;
    final showAchievement = avgCompletion >= 80 && _chartAnimationValue >= 1.0;
    
    // Determine label interval based on data count to avoid overlap
    final labelInterval = display.length > 12 ? 2 : 1;
    
    // Calculate dynamic bar width based on data count
    final barWidthBase = display.length <= 7 ? 28.0 : display.length <= 12 ? 22.0 : 16.0;

    final chartWidget = LayoutBuilder(
      builder: (context, constraints) {
        // Responsive height based on screen width
        final chartHeight = constraints.maxWidth < 400 ? 260.0 : 320.0;
        
        return SizedBox(
          height: chartHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              BarChart(
                BarChartData(
                  barGroups: completionBars.map((bar) {
                    return BarChartGroupData(
                      x: bar.x,
                      barRods: bar.barRods.map((rod) {
                        return BarChartRodData(
                          toY: rod.toY,
                          width: barWidthBase,
                          color: rod.color,
                          borderRadius: rod.borderRadius,
                          gradient: rod.gradient,
                          backDrawRodData: rod.backDrawRodData,
                        );
                      }).toList(),
                      showingTooltipIndicators: bar.showingTooltipIndicators,
                    );
                  }).toList(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (response == null || response.spot == null) return;
                      final idx = response.spot!.touchedBarGroup.x.toInt();
                      final item = display[idx];
                      _showDetailModal(item, display);
                    },
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBorder: BorderSide.none,
                      tooltipRoundedRadius: 16,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      tooltipMargin: 10,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (group) => AppColors.surfaceDark,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = display[group.x.toInt()];
                        final pct = (item['completionPercent'] ?? 0).toStringAsFixed(0);
                        
                        // Eco-themed emoji based on completion
                        String emoji = '🌱';
                        final pctNum = double.tryParse(pct) ?? 0;
                        if (pctNum >= 80) emoji = '🌳';
                        else if (pctNum >= 60) emoji = '🌿';
                        else if (pctNum >= 40) emoji = '🌱';
                        else if (pctNum >= 20) emoji = '🍃';
                        else emoji = '🌍';
                        
                        return BarTooltipItem(
                          '$emoji  Green Score: $pct%',
                          GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.5,
                            letterSpacing: -0.2,
                          ),
                        );
                      },
                    ),
                  ),
                  maxY: 100,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: labelInterval.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= display.length) return const SizedBox();
                          // Skip labels based on interval to prevent overlap
                          if (idx % labelInterval != 0) return const SizedBox();

                          final item = display[idx];
                          String label = '';
                          
                          if (item.containsKey('label')) {
                            if (_range == 'monthly') {
                              label = 'W${idx + 1}';
                            } else {
                              label = item['label'].toString();
                            }
                          } else if (item.containsKey('day')) {
                            label = item['day'].toString();
                          } else if (item.containsKey('date')) {
                            final d = item['date'].toString();
                            if (_range == 'weekly') {
                              try {
                                final dt = DateTime.parse(d);
                                label = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
                              } catch (_) {
                                label = d.substring(5);
                              }
                            } else if (_range == 'monthly') {
                              try {
                                final dt = DateTime.parse(d);
                                final day = dt.day;
                                final weekNum = ((day - 1) ~/ 7) + 1;
                                if ((day - 1) % 7 == 0 && weekNum <= 5) {
                                  label = 'W$weekNum';
                                }
                              } catch (_) {
                                label = '';
                              }
                            } else {
                              try {
                                final dt = DateTime.parse(d);
                                label = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1];
                              } catch (_) {
                                label = d.substring(5, 7);
                              }
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              label,
                              style: GoogleFonts.manrope(
                                fontSize: _range == 'yearly' ? 10 : 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                        reservedSize: 32,
                      ),
                    ),
                leftTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco, size: 12, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Green Score %',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      final v = value.toInt();
                      final ticks = [0, 25, 50, 75, 100];
                      if (!ticks.contains(v)) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          '$v',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryLight,
                            letterSpacing: -0.2,
                          ),
                        ),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                rightTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 12, color: secondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Wellness',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      final v = value.toInt();
                      if (v % 20 != 0) return const SizedBox.shrink();
                      final hap = (v / 10).toInt();
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(
                          '$hap',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: secondaryColor,
                          ),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) {
                  // Goal line at 80%
                  if (value == 80) {
                    return FlLine(
                      color: successColor,
                      strokeWidth: 2,
                      dashArray: [8, 4],
                    );
                  }
                  return FlLine(
                    color: AppColors.textSecondaryLight.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [6, 4],
                  );
                },
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 80,
                    color: successColor.withOpacity(0.7),
                    strokeWidth: 2,
                    dashArray: [8, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, bottom: 5),
                      style: GoogleFonts.manrope(
                        color: successColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      labelResolver: (line) => '🎯 Goal',
                    ),
                  ),
                ],
              ),
              borderData: FlBorderData(show: false),
              alignment: BarChartAlignment.spaceAround,
            ),
          ),
          // Line chart overlay for happiness/wellness trend
          LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: happinessSpots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  preventCurveOverShooting: true,
                  color: secondaryColor,
                  barWidth: 3,
                  shadow: Shadow(
                    color: secondaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        secondaryColor.withOpacity(0.25),
                        secondaryColor.withOpacity(0.1),
                        secondaryColor.withOpacity(0.02),
                        secondaryColor.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final happiness = spot.y / 10;
                      Color dotBorder = secondaryColor;
                      if (happiness >= 8) {
                        dotBorder = successColor;
                      } else if (happiness >= 6) {
                        dotBorder = AppColors.info;
                      } else if (happiness < 4) {
                        dotBorder = errorColor;
                      }
                      
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: dotBorder,
                      );
                    },
                  ),
                  isStrokeCapRound: true,
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 12,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (spot) => AppColors.surfaceDark,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final happiness = (spot.y / 10).toStringAsFixed(1);
                      return LineTooltipItem(
                        '💚 Wellness: $happiness/10',
                        GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              maxY: 100,
              minY: 0,
              minX: -0.5,
              maxX: (display.length - 0.5),
            ),
          ),
          // Achievement badge overlay
          if (showAchievement)
            Positioned(
              top: 8,
              right: 8,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [warningColor.withOpacity(0.9), const Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: warningColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            'Eco Champion!',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
      },
    );
    
    // Return chart only (removed smart insights)
    return chartWidget;
  }

  void _showDetailModal(Map<String, dynamic> item, List<Map<String, dynamic>> display) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final items = (item['items'] as List<dynamic>?) ?? [item];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.calendar_today, color: primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['label'] ?? item['date'] ?? 'Details',
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              '${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey.withOpacity(0.2)),
                      itemBuilder: (context, idx) {
                        final d = items[idx];
                        final date = d['date'] ?? d['label'] ?? '';
                        final hap = ((d['happiness'] ?? 0) as num).toDouble();
                        final pct = ((d['completionPercent'] ?? 0) as num).toDouble();
                        final cnt = d['count'] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      date.toString(),
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$cnt ${cnt == 1 ? 'activity' : 'activities'}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildMetricChip('😊 ${hap.toStringAsFixed(1)}', Colors.blue),
                              const SizedBox(width: 8),
                              _buildMetricChip('${pct.toStringAsFixed(0)}%', primaryColor),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Help dialog removed along with diagnostic UI
  
  /// Build a circular progress view for daily data
  Widget _buildDailyProgressView(Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completion = ((data['completionPercent'] ?? 0) as num).toDouble();
    final happiness = ((data['happiness'] ?? 0) as num).toDouble();
    final count = (data['count'] ?? 0) as int;
    
    // Eco-themed color based on completion
    Color progressColor;
    String ecoMessage;
    String ecoEmoji;
    
    if (completion >= 80) {
      progressColor = const Color(0xFF2E7D32);
      ecoMessage = 'Eco Champion!';
      ecoEmoji = '🌳';
    } else if (completion >= 60) {
      progressColor = const Color(0xFF43A047);
      ecoMessage = 'Great Progress!';
      ecoEmoji = '🌿';
    } else if (completion >= 40) {
      progressColor = primaryColor;
      ecoMessage = 'On Track!';
      ecoEmoji = '🌱';
    } else if (completion >= 20) {
      progressColor = const Color(0xFF66BB6A);
      ecoMessage = 'Getting Started';
      ecoEmoji = '🍃';
    } else {
      progressColor = Colors.grey;
      ecoMessage = 'Start Your Journey';
      ecoEmoji = '🌍';
    }
    
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 12,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  // Progress circle
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: CircularProgressIndicator(
                      value: completion / 100,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  // Center content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(ecoEmoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        '${completion.toStringAsFixed(0)}%',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Green Score',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            Text(
              ecoMessage,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: progressColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDailyStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _placeholderChart(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              height: 260,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withOpacity(0.5)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : primaryColor.withOpacity(0.15),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.eco_outlined,
                      size: 40,
                      color: primaryColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: GoogleFonts.manrope(
                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start logging activities to see your progress!',
                    style: GoogleFonts.manrope(
                      color: isDark ? Colors.white38 : AppColors.textSecondaryLight.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchSeries();
            if (_usagePermission) await _fetchUsage();
          },
          color: primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, const Color(0xFF43A047)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.eco, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Eco Impact",
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              "Track your green journey 🌱",
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quick access: open wearable sync screen
                      IconButton(
                        tooltip: 'Sync wearables',
                        icon: const Icon(Icons.watch, size: 22),
                        color: isDark ? Colors.white70 : Colors.black54,
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to sync wearables')));
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => IntegrationProgressScreen(uid: user.uid)));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Range Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildRangeButton('daily', 'Day', Icons.today),
                        _buildRangeButton('weekly', 'Week', Icons.calendar_view_week),
                        _buildRangeButton('monthly', 'Month', Icons.calendar_today),
                        _buildRangeButton('yearly', 'Year', Icons.calendar_month),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (_loading)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          CircularProgressIndicator(color: primaryColor),
                          const SizedBox(height: 16),
                          Text(
                            'Loading your progress...',
                            style: GoogleFonts.manrope(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load data',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _error!,
                            style: GoogleFonts.manrope(fontSize: 12, color: Colors.red[700]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchSeries,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Today's Activity Progress Card (for daily view)
                    if (_range == 'daily') ...[
                      _buildTodayActivityProgressCard(context),
                      const SizedBox(height: 16),
                    ],
                    
                    // Summary Cards Row - Centered Green Score
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            context,
                            icon: Icons.favorite_rounded,
                            title: 'Wellness Score',
                            value: _avgHappiness().toStringAsFixed(1),
                            suffix: '/10',
                            color: const Color(0xFFE91E63),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            context,
                            icon: Icons.eco,
                            title: _range == 'daily' ? 'Eco Actions' : 'Green Score',
                            value: _range == 'daily' 
                                ? '$_todayCompletedCount/$_todayExpectedCount' 
                                : _avgCompletion().toStringAsFixed(0),
                            suffix: _range == 'daily' ? '' : '%',
                            color: primaryColor,
                            gradient: LinearGradient(
                              colors: [primaryColor, const Color(0xFF2E7D32)],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Main Chart Card
                      _buildChartCard(
                      context,
                      title: "Performance Trends",
                      subtitle: _range == 'daily'
                          ? "Today's Impact"
                          : _range == 'weekly'
                          ? "Weekly Progress"
                          : _range == 'monthly'
                              ? "Monthly Impact"
                              : "Yearly Journey",
                      chartWidget: _buildCharts(),
                      showLegend: false,
                    ),
                      const SizedBox(height: 12),
                      // (Diagnostic Usage Access panel removed)
                    
                    if (_series.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildChangeIndicator(context),
                    ],
                  ],
                  
                  const SizedBox(height: 20),
                  // Total screen time card removed - showing only social media usage
                  // _screenTimeCard(context),
                  _buildSocialMediaBreakdown(context),
                  const SizedBox(height: 20),
                  // Inline wearable summaries (compact metric cards)
                  if (_fitbitData != null || _fitbitSummary != null) ...[
                    Align(alignment: Alignment.centerLeft, child: Text('Fitbit', style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    _buildWearableSummaryCard(context, _fitbitData ?? {}, 'fitbit'),
                    const SizedBox(height: 12),
                  ],
                  if (_samsungData != null || _samsungSummary != null) ...[
                    Align(alignment: Alignment.centerLeft, child: Text('Samsung', style: TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    _buildWearableSummaryCard(context, _samsungData ?? {}, 'samsung'),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeButton(String value, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _range == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (value != _range) {
            setState(() => _range = value);
            _fetchSeries();
            if (_usagePermission) _fetchUsage();
            // reload wearable aggregates for new range
            _loadWearableAggregates();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withOpacity(0.1) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build today's activity progress card with visual progress indicator
  Widget _buildTodayActivityProgressCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressPercent = _todayExpectedCount > 0 
        ? _todayCompletedCount / _todayExpectedCount 
        : 0.0;
    
    // Get emoji and color based on progress - eco-themed
    String progressEmoji;
    String progressMessage;
    Color progressColor;
    IconData progressIcon;
    
    if (_todayCompletionPercent >= 80) {
      progressEmoji = '🌳';
      progressMessage = 'Eco champion! You\'re making Earth proud!';
      progressColor = const Color(0xFF2E7D32);
      progressIcon = Icons.park;
    } else if (_todayCompletionPercent >= 60) {
      progressEmoji = '🌿';
      progressMessage = 'Fantastic green progress!';
      progressColor = const Color(0xFF43A047);
      progressIcon = Icons.eco;
    } else if (_todayCompletionPercent >= 40) {
      progressEmoji = '🌱';
      progressMessage = 'Growing your eco footprint!';
      progressColor = primaryColor;
      progressIcon = Icons.grass;
    } else if (_todayCompletionPercent >= 20) {
      progressEmoji = '🍃';
      progressMessage = 'Every green action matters!';
      progressColor = const Color(0xFF66BB6A);
      progressIcon = Icons.nature;
    } else {
      progressEmoji = '🌍';
      progressMessage = 'Start your eco journey today!';
      progressColor = const Color(0xFF81C784);
      progressIcon = Icons.public;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            progressColor.withAlpha(35),
            progressColor.withAlpha(15),
            isDark ? Colors.grey.shade900 : Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: progressColor.withAlpha(50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: progressColor.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [progressColor.withAlpha(50), progressColor.withAlpha(25)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withAlpha(30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  progressEmoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(progressIcon, size: 14, color: progressColor),
                        const SizedBox(width: 4),
                        Text(
                          "TODAY'S ECO PROGRESS",
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_todayCompletedCount',
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: progressColor,
                            ),
                          ),
                          TextSpan(
                            text: ' of $_todayExpectedCount',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [progressColor, progressColor.withAlpha(200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withAlpha(80),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$_todayCompletionPercent%',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Progress bar with nature element
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressPercent.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              if (progressPercent > 0.15)
                Positioned(
                  left: (MediaQuery.of(context).size.width - 80) * progressPercent.clamp(0.0, 1.0) - 8,
                  top: -2,
                  child: Icon(Icons.eco, size: 16, color: Colors.white.withAlpha(220)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Motivational message
          Row(
            children: [
              Icon(
                _todayCompletionPercent >= 60 ? Icons.trending_up : Icons.tips_and_updates,
                size: 18,
                color: progressColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progressMessage,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEcoImpactStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String suffix,
    required Color color,
    required Gradient gradient,
  }) {
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text(
                  suffix,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget chartWidget,
    bool showLegend = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDark 
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1a1a1a),
                  const Color(0xFF2d2d2d).withOpacity(0.8),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.3)
                : primaryColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(Icons.insights, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1a1a1a),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showLegend) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem('Completion', primaryColor, isDark),
                  Container(
                    width: 1,
                    height: 16,
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                  ),
                  _buildLegendItem('Happiness', secondaryColor, isDark),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          chartWidget,
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildChangeIndicator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = _isPositiveChange();
    final changeText = _changeText();
    
    if (changeText.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isPositive ? Colors.green : Colors.orange).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.orange).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.trending_up : Icons.trending_flat,
              color: isPositive ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? 'Great Progress!' : 'Keep Going!',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  changeText,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Removed total screen time card - showing only social media usage
  
  /// Build social media usage breakdown below main digital wellbeing card
  Widget _buildSocialMediaBreakdown(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show card even if empty, with permission prompt or "no data" message
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digital Wellness',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Track screen time for better balance',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Time range badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _range == 'daily' ? 'Today' : _range == 'weekly' ? '7 Days' : _range == 'monthly' ? 'Month' : 'Year',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show permission prompt if not granted
          if (!_usagePermission)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.withAlpha(20), Colors.purple.withAlpha(10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withAlpha(50)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: Colors.blue, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Enable Usage Access',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track your digital habits and improve focus',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await DigitalWellbeingService.openPermissionSettings();
                        // Wait a bit for system to update permission state
                        await Future.delayed(const Duration(milliseconds: 800));
                        // Retry permission check up to 3 times with delay
                        for (int i = 0; i < 3; i++) {
                          final granted = await DigitalWellbeingService.isPermissionGranted();
                          if (granted) {
                            if (mounted) {
                              setState(() => _usagePermission = true);
                              await _fetchUsage();
                            }
                            break;
                          }
                          await Future.delayed(const Duration(milliseconds: 500));
                        }
                      },
                      icon: const Icon(Icons.security, size: 18),
                      label: Text(
                        'Grant Permission',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            )
          // Show "no data" message if permission granted but no apps found
          else if (_socialMediaApps.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]?.withAlpha(100) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.celebration_outlined, color: primaryColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Great job! 🌱',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No social media usage detected',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your digital wellness is on track!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _fetchUsage,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          // Show actual usage data
          else
            Column(
              children: [
                // Total usage summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade100.withAlpha(80),
                        Colors.red.shade100.withAlpha(40),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.orange.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Social Media Time',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              _formatTotalUsage(),
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildUsageIndicator(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // App list
                ..._socialMediaApps.map((app) => _buildAppUsageItem(app, isDark)),
              ],
            ),
        ],
      ),
    );
  }
  
  String _formatTotalUsage() {
    if (_socialMediaApps.isEmpty) return '0m';
    final totalMinutes = _socialMediaApps.fold<double>(0, (total, app) => total + ((app['minutes'] as num?)?.toDouble() ?? 0));
    if (totalMinutes >= 60) {
      final hours = (totalMinutes / 60).floor();
      final mins = (totalMinutes % 60).round();
      return '${hours}h ${mins}m';
    }
    return '${totalMinutes.round()}m';
  }
  
  Widget _buildUsageIndicator() {
    final totalMinutes = _socialMediaApps.fold<double>(0, (total, app) => total + ((app['minutes'] as num?)?.toDouble() ?? 0));
    Color color;
    IconData icon;
    String label;
    
    if (totalMinutes < 60) {
      color = primaryColor;
      icon = Icons.thumb_up;
      label = 'Great';
    } else if (totalMinutes < 120) {
      color = Colors.orange;
      icon = Icons.warning_amber;
      label = 'Moderate';
    } else {
      color = Colors.red;
      icon = Icons.warning;
      label = 'High';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppUsageItem(Map<String, dynamic> app, bool isDark) {
    final appName = app['appName'] as String? ?? 'Unknown App';
    final minutes = (app['minutes'] as num?)?.toDouble() ?? 0.0;
    final hours = (minutes / 60.0);
    
    // Get app-specific icon and color
    IconData appIcon;
    Color appColor;
    
    final lowerName = appName.toLowerCase();
    if (lowerName.contains('instagram')) {
      appIcon = Icons.camera_alt;
      appColor = Colors.pink;
    } else if (lowerName.contains('facebook')) {
      appIcon = Icons.facebook;
      appColor = Colors.blue;
    } else if (lowerName.contains('twitter') || lowerName.contains('x')) {
      appIcon = Icons.alternate_email;
      appColor = Colors.lightBlue;
    } else if (lowerName.contains('tiktok')) {
      appIcon = Icons.music_note;
      appColor = Colors.black87;
    } else if (lowerName.contains('youtube')) {
      appIcon = Icons.play_circle_fill;
      appColor = Colors.red;
    } else if (lowerName.contains('snapchat')) {
      appIcon = Icons.flash_on;
      appColor = Colors.yellow.shade700;
    } else if (lowerName.contains('whatsapp')) {
      appIcon = Icons.chat;
      appColor = Colors.green;
    } else if (lowerName.contains('telegram')) {
      appIcon = Icons.send;
      appColor = Colors.lightBlue;
    } else if (lowerName.contains('reddit')) {
      appIcon = Icons.reddit;
      appColor = Colors.deepOrange;
    } else if (lowerName.contains('linkedin')) {
      appIcon = Icons.work;
      appColor = Colors.blue.shade800;
    } else if (lowerName.contains('pinterest')) {
      appIcon = Icons.push_pin;
      appColor = Colors.red.shade700;
    } else if (lowerName.contains('discord')) {
      appIcon = Icons.headphones;
      appColor = Colors.indigo;
    } else {
      appIcon = Icons.apps;
      appColor = Colors.blueGrey;
    }
    
    // Calculate progress (assuming 2 hours = 100% for visualization)
    final progress = (minutes / 120).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]?.withAlpha(100) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // App icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: appColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(appIcon, color: appColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hours >= 1 ? '${hours.toStringAsFixed(1)} hours' : '${minutes.toStringAsFixed(0)} min',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Usage time badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: appColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hours >= 1 ? '${hours.toStringAsFixed(1)}h' : '${minutes.toStringAsFixed(0)}m',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: appColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey.withAlpha(40),
              valueColor: AlwaysStoppedAnimation<Color>(appColor.withAlpha(180)),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a compact summary card for wearable metrics (steps, resting HR, sleep)
  Widget _buildWearableSummaryCard(BuildContext context, Map<String, dynamic> data, String source) {
    // Prefer aggregated summaries from Firestore when available for accuracy
    Map<String, dynamic>? agg = source == 'fitbit' ? _fitbitSummary : _samsungSummary;
    final parsed = source == 'fitbit' ? _parseFitbitMetrics(data) : _parseSamsungMetrics(data);
    final metrics = agg ?? parsed;
    // Compose steps display with simple trend indicator when available
    String stepsDisplay;
    if (metrics['steps'] != null) {
      stepsDisplay = _formatNumber(metrics['steps'] as int?);
      final tp = metrics['trendPercent'] as double?;
      if (tp != null) {
        final arrow = tp > 0 ? '↑' : (tp < 0 ? '↓' : '→');
        stepsDisplay = '$stepsDisplay $arrow ${tp.abs().toStringAsFixed(0)}%';
      }
    } else {
      stepsDisplay = 'N/A';
    }
    final label = _range == 'daily' ? 'Today' : _range == 'weekly' ? 'Last 7 days' : _range == 'monthly' ? 'This month' : 'This year';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSmallMetric(Icons.directions_walk, 'Steps', stepsDisplay)),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallMetric(Icons.favorite, 'Resting HR', metrics['hr'] != null ? '${metrics['hr']!.toStringAsFixed(0)} bpm' : 'N/A')),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallMetric(Icons.bedtime, 'Sleep', metrics['sleep'] != null ? '${metrics['sleep']!.toStringAsFixed(1)} h' : 'N/A')),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(source.toUpperCase(), style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.blueGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _parseFitbitMetrics(Map<String, dynamic> raw) {
    try {
      var data = Map<String, dynamic>.from(raw);
      // unwind common wrapping
      if (data.containsKey('fitbit_steps_payload') && data['fitbit_steps_payload'] is Map) {
        data = Map<String, dynamic>.from(data['fitbit_steps_payload'] as Map);
      }

      int? steps;
      double? hr;
      double? sleepHours;

      // Steps: activities-steps (list of {dateTime, value}) or activities list with steps
      if (data['activities-steps'] is List) {
        final list = List.from(data['activities-steps'] as List);
        if (list.isNotEmpty) {
          // sum last N entries depending on range (best-effort)
          final take = _range == 'daily' ? 1 : _range == 'weekly' ? 7 : _range == 'monthly' ? list.length : list.length;
          final sliced = list.reversed.take(take);
          int total = 0;
          for (final e in sliced) {
            final v = e is Map && e['value'] != null ? int.tryParse(e['value'].toString()) ?? 0 : 0;
            total += v;
          }
          steps = total;
        }
      } else if (data['activities'] is List) {
        try {
          final list = List.from(data['activities'] as List);
          if (list.isNotEmpty) {
            steps = list.map<int>((e) => (e['steps'] as num?)?.toInt() ?? 0).fold<int>(0, (int a, int b) => a + b);
          }
        } catch (_) {}
      }

      // Heart: activities-heart -> value.restingHeartRate
      if (data['activities-heart'] is List) {
        try {
          final list = List.from(data['activities-heart'] as List);
          final take = _range == 'daily' ? 1 : _range == 'weekly' ? 7 : list.length;
          final sliced = list.reversed.take(take).where((e) => e is Map && e['value'] is Map);
          final hrVals = <double>[];
          for (final e in sliced) {
            final v = (e['value'] as Map)['restingHeartRate'];
            if (v != null) hrVals.add((v as num).toDouble());
          }
          if (hrVals.isNotEmpty) hr = hrVals.reduce((a, b) => a + b) / hrVals.length;
        } catch (_) {}
      }

      // Sleep: sleep list entries may contain minutesAsleep or totalMinutesAsleep
      if (data['sleep'] is List) {
        try {
          final list = List.from(data['sleep'] as List);
          final take = _range == 'daily' ? 1 : _range == 'weekly' ? 7 : list.length;
          final sliced = list.reversed.take(take);
          double totalMins = 0;
          int count = 0;
          for (final s in sliced) {
            if (s is Map) {
              final mins = (s['minutesAsleep'] ?? s['totalMinutesAsleep'] ?? s['duration']) as num?;
              if (mins != null) {
                // duration might be ms; if large assume ms
                final m = mins.toDouble();
                totalMins += (m > 100000 ? m / 60000.0 : m);
                count++;
              }
            }
          }
          if (count > 0) sleepHours = totalMins / 60.0 / ( _range == 'weekly' ? count : 1 );
        } catch (_) {}
      }

      return {'steps': steps, 'hr': hr, 'sleep': sleepHours};
    } catch (_) {
      return {'steps': null, 'hr': null, 'sleep': null};
    }
  }

  Map<String, dynamic> _parseSamsungMetrics(Map<String, dynamic> raw) {
    try {
      final data = Map<String, dynamic>.from(raw);
      int? steps;
      double? hr;
      double? sleepHours;

      // Samsung payloads vary by plugin; try common keys
      if (data.containsKey('steps')) {
        final s = data['steps'];
        if (s is num) steps = s.toInt();
        else if (s is Map && s['total'] != null) steps = (s['total'] as num).toInt();
      }

      if (steps == null) {
        // try activities array
        if (data['activities'] is List) {
          try {
            final list = List.from(data['activities'] as List);
            steps = list.map<int>((e) => (e['steps'] as num?)?.toInt() ?? 0).fold<int>(0, (int a, int b) => a + b);
          } catch (_) {}
        }
      }

      if (data.containsKey('heart_rate')) {
        final h = data['heart_rate'];
        if (h is num) hr = h.toDouble();
        else if (h is Map && h['resting'] != null) hr = (h['resting'] as num).toDouble();
      }

      if (data.containsKey('sleep')) {
        final s = data['sleep'];
  if (s is num) sleepHours = s.toDouble();
  else if (s is Map && s['hours'] != null) sleepHours = (s['hours'] as num).toDouble();
      }

      return {'steps': steps, 'hr': hr, 'sleep': sleepHours};
    } catch (_) {
      return {'steps': null, 'hr': null, 'sleep': null};
    }
  }

  String _formatNumber(int? n) {
    if (n == null) return 'N/A';
    try {
      return NumberFormat.decimalPattern().format(n);
    } catch (_) {
      return n.toString();
    }
  }

  /// Load aggregated wearable metrics from Firestore 'daily_metrics' for the signed-in user
  Future<void> _loadWearableAggregates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;
      if (_range == 'weekly') {
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      } else if (_range == 'monthly') {
        start = DateTime(now.year, now.month, 1);
      } else {
        start = DateTime(now.year, 1, 1);
      }

      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);

    final snap = await FirebaseFirestore.instance
          .collection('daily_metrics')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();

      int stepsFit = 0;
      final hrFitVals = <double>[];
      double sleepFitSum = 0;
      int sleepFitCount = 0;

      int stepsSam = 0;
      final hrSamVals = <double>[];
      double sleepSamSum = 0;
      int sleepSamCount = 0;

      for (final doc in snap.docs) {
        final d = doc.data();
        final fit = d['fitbit'] as Map<String, dynamic>?;
        final sam = d['samsung'] as Map<String, dynamic>?;
        if (fit != null) {
          final p = _parseFitbitMetrics(fit);
          if (p['steps'] is int) stepsFit += p['steps'] as int;
          if (p['hr'] is double) hrFitVals.add(p['hr'] as double);
          if (p['sleep'] is double) { sleepFitSum += p['sleep'] as double; sleepFitCount++; }
        }
        if (sam != null) {
          final p = _parseSamsungMetrics(sam);
          if (p['steps'] is int) stepsSam += p['steps'] as int;
          if (p['hr'] is double) hrSamVals.add(p['hr'] as double);
          if (p['sleep'] is double) { sleepSamSum += p['sleep'] as double; sleepSamCount++; }
        }
      }

      final fitHrAvg = hrFitVals.isNotEmpty ? hrFitVals.reduce((a, b) => a + b) / hrFitVals.length : null;
      final fitSleepAvg = sleepFitCount > 0 ? (sleepFitSum / sleepFitCount) : null;
      final samHrAvg = hrSamVals.isNotEmpty ? hrSamVals.reduce((a, b) => a + b) / hrSamVals.length : null;
      final samSleepAvg = sleepSamCount > 0 ? (sleepSamSum / sleepSamCount) : null;

      // --- previous period comparison for simple trend indicator ---
      DateTime prevStart;
      DateTime prevEnd;
      if (_range == 'weekly') {
        prevStart = start.subtract(const Duration(days: 7));
        prevEnd = start.subtract(const Duration(days: 1));
      } else if (_range == 'monthly') {
        prevStart = DateTime(start.year, start.month - 1, 1);
        prevEnd = DateTime(start.year, start.month, 0);
      } else {
        prevStart = DateTime(start.year - 1, 1, 1);
        prevEnd = DateTime(start.year - 1, 12, 31);
      }
      final prevStartStr = prevStart.toIso8601String().substring(0, 10);
      final prevEndStr = prevEnd.toIso8601String().substring(0, 10);

      final prevSnap = await FirebaseFirestore.instance
          .collection('daily_metrics')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: prevStartStr)
          .where('date', isLessThanOrEqualTo: prevEndStr)
          .get();

      int prevFitSteps = 0;
      int prevSamSteps = 0;
      for (final doc in prevSnap.docs) {
        final d = doc.data();
        final fit = d['fitbit'] as Map<String, dynamic>?;
        final sam = d['samsung'] as Map<String, dynamic>?;
        if (fit != null) {
          final p = _parseFitbitMetrics(fit);
          if (p['steps'] is int) prevFitSteps += p['steps'] as int;
        }
        if (sam != null) {
          final p = _parseSamsungMetrics(sam);
          if (p['steps'] is int) prevSamSteps += p['steps'] as int;
        }
      }

      double? fitTrendPct;
      if (prevFitSteps > 0) fitTrendPct = ((stepsFit - prevFitSteps) / prevFitSteps) * 100.0;
      double? samTrendPct;
      if (prevSamSteps > 0) samTrendPct = ((stepsSam - prevSamSteps) / prevSamSteps) * 100.0;

      setState(() {
        _fitbitSummary = {
          'steps': stepsFit > 0 ? stepsFit : null,
          'hr': fitHrAvg,
          'sleep': fitSleepAvg,
          'trendPercent': fitTrendPct,
        };
        _samsungSummary = {
          'steps': stepsSam > 0 ? stepsSam : null,
          'hr': samHrAvg,
          'sleep': samSleepAvg,
          'trendPercent': samTrendPct,
        };
      });
    } catch (e) {
      // ignore failures silently; keep current summaries
    }
  }
}