import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// SessionManager keeps track of the user's last activity timestamp and
/// automatically signs them out after a configured inactivity duration.
class SessionManager with WidgetsBindingObserver {
  SessionManager._private();

  static final SessionManager instance = SessionManager._private();

  static const _prefsKey = 'session_last_activity_millis';

  late final FirebaseAuth _auth;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Public navigatorKey for wiring into MaterialApp.navigatorKey
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;
  Duration inactivityDuration = const Duration(days: 20);

  Timer? _checkTimer;
  StreamSubscription<User?>? _authSub;

  bool _initialized = false;

  /// Initialize the session manager. Call once early in app startup.
  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    Duration? inactivity,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _auth = FirebaseAuth.instance;
    _navigatorKey = navigatorKey;
    if (inactivity != null) inactivityDuration = inactivity;

    WidgetsBinding.instance.addObserver(this);

    // Keep a subscription to auth state so we can start/stop the timer
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        // Signed in: ensure we have a last-activity marker and start checking
        await registerActivity();
        _startTimer();
      } else {
        // Signed out: stop checking
        await _clearLastActivity();
        _stopTimer();
      }
    });
  }

  /// Record that the user interacted with the app right now.
  Future<void> registerActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, DateTime.now().toUtc().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<int?> _getLastActivityMillis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_prefsKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  void _startTimer() {
    _stopTimer();
    // Check every hour. Also ensures a check occurs if app stays open for long.
    _checkTimer = Timer.periodic(const Duration(hours: 1), (_) => _checkExpiry());
  }

  void _stopTimer() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _checkExpiry() async {
    try {
      final lastMillis = await _getLastActivityMillis();
      if (lastMillis == null) return; // nothing to check
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis, isUtc: true).toLocal();
      final now = DateTime.now();
      if (now.difference(last) >= inactivityDuration) {
        // Expired — sign the user out locally and navigate to login.
        await _performSignOut();
      }
    } catch (_) {}
  }

  Future<void> _performSignOut() async {
    try {
      // Stop timer immediately to avoid races
      _stopTimer();
      await AuthService().signOut();
      await _clearLastActivity();

      // Navigate to login, if possible
      final nav = _navigatorKey?.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (_) {}
  }

  /// WidgetsBindingObserver override — app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app becomes visible again, consider that an activity
    if (state == AppLifecycleState.resumed) {
      registerActivity();
      _checkExpiry();
    }
    // If app is paused we persist the timestamp (it's already saved by register)
  }

  /// Manually trigger an expiry check (useful after pointer events)
  Future<void> manualCheck() async => _checkExpiry();

  /// Dispose resources. Not strictly needed for app lifetime singletons,
  /// but provided for completeness.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _authSub?.cancel();
    _stopTimer();
    _initialized = false;
  }
}
