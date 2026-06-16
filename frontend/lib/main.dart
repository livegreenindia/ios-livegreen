import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/pages/progress_refresh_notifier.dart';
import 'services/subscription_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'config/routes.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/location_tracking_service.dart';
import 'services/mindfulness_bell_scheduler.dart';
import 'screens/splash_wrapper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint(
        '[Notifications] Background message: ${message.notification?.title}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be ready before the UI reads auth state, but it must never
  // be allowed to hang startup. Bound it with a timeout and never let a failure
  // stop us from rendering the first frame.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 20));

    // Enable Firestore offline persistence for better UX
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize Firebase Cloud Messaging background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Enable persistent auth - keeps user signed in (web only)
    // `setPersistence` is a web-only API; guard it to avoid runtime errors on mobile.
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e, st) {
    debugPrint('[Startup] Firebase initialization failed: $e\n$st');
  }

  final navigatorKey = GlobalKey<NavigatorState>();

  // Render the UI immediately. The services below do not need to complete
  // before the first frame, and awaiting them here previously left iOS stuck
  // on the launch screen (e.g. FirebaseMessaging.getToken() can block waiting
  // for an APNs token). They now initialize in the background, each guarded so
  // a single failure or hang can never prevent the app from starting.
  runApp(LiveGreenApp(navigatorKey: navigatorKey));

  _initServicesInBackground(navigatorKey);
}

/// Best-effort background initialization for non-critical startup services.
/// Each step is wrapped so a failure or hang cannot block the app from running.
Future<void> _initServicesInBackground(
    GlobalKey<NavigatorState> navigatorKey) async {
  Future<void> guard(String name, Future<void> Function() task) async {
    try {
      await task().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Startup] $name initialization skipped: $e');
    }
  }

  await guard('Notifications', NotificationService.initialize);
  await guard('MindfulnessBell', () async {
    await MindfulnessBellScheduler.initialize();
    await MindfulnessBellScheduler.restoreReminderIfEnabled();
  });
  // Location permission is now requested when needed (not at startup)

  // Initialize the session manager so it can observe auth state and manage
  // inactivity-based expiry. The navigatorKey lets it navigate to the login
  // screen when the session expires.
  await guard('SessionManager',
      () => SessionManager.instance.init(navigatorKey: navigatorKey));

  // Initialize deep link service for club sharing
  await guard('DeepLink', () => DeepLinkService.initialize(navigatorKey));

  // If running against a local backend, connect to emulators for faster dev.
  const localHosts = ['127.0.0.1', 'localhost'];
  final apiBase =
      const String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (localHosts.any((h) => apiBase.contains(h))) {
    try {
      FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      await AuthService().ensureSignedInForDev();
    } catch (e) {
      // ignore errors here; dev auto-signin is best-effort
    }
  }
}

class LiveGreenApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const LiveGreenApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressRefreshNotifier()),
        ChangeNotifierProvider(
          create: (_) {
            final subs = SubscriptionService();
            // Initialize subscription state whenever a user is signed in.
            // Guard against duplicate calls (e.g. token-refresh auth events)
            // by checking whether initialization is already in progress.
            String? _lastInitUid;
            FirebaseAuth.instance.authStateChanges().listen((user) {
              if (user != null && user.uid != _lastInitUid) {
                _lastInitUid = user.uid;
                subs.initialize();
              } else if (user == null) {
                _lastInitUid = null;
              }
            });
            return subs;
          },
        ),
      ],
      child: MaterialApp(
        title: 'LiveGreen',
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        onGenerateRoute: AppRoutes.generateRoute,
        home: const SplashWrapper(),
      ),
    );
  }
}
