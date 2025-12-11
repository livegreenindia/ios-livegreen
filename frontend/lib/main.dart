import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/pages/progress_refresh_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'config/routes.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/location_tracking_service.dart';
import 'screens/splash_wrapper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('[Notifications] Background message: ${message.notification?.title}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable Firestore offline persistence for better UX
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Initialize Firebase Cloud Messaging background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  await NotificationService.initialize();
  
  // Initialize location permission at startup
  await LocationTrackingService.initializePermission();
  
  // Enable persistent auth - keeps user signed in (web only)
  // `setPersistence` is a web-only API; guard it to avoid runtime errors on mobile.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  
  // If API_BASE_URL or running locally, connect to emulators for faster dev
  const localHosts = ['127.0.0.1', 'localhost'];
  final apiBase = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
  final isLocal = localHosts.any((h) => apiBase.contains(h));
  if (isLocal) {
    // Connect Auth to emulator
    FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    // Auto sign-in test user for local development to ensure ID token is present
    try {
      await AuthService().ensureSignedInForDev();
    } catch (e) {
      // ignore errors here; dev auto-signin is best-effort
    }
  }
  // Initialize the session manager so it can observe auth state and manage
  // inactivity-based expiry. Provide a navigatorKey so it can navigate to the
  // login screen when the session expires.
  final navigatorKey = GlobalKey<NavigatorState>();
  await SessionManager.instance.init(navigatorKey: navigatorKey);

  runApp(LiveGreenApp(navigatorKey: navigatorKey));
}

class LiveGreenApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const LiveGreenApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProgressRefreshNotifier(),
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
