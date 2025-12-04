import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Cloud Messaging (push notifications)
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Initialize notification service and request permissions
  static Future<void> initialize() async {
    try {
      // Request permission for iOS and web
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('[Notifications] User granted permission');
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        if (kDebugMode) {
          print('[Notifications] User granted provisional permission');
        }
      } else {
        if (kDebugMode) {
          print('[Notifications] User declined or has not accepted permission');
        }
        return;
      }

      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          print('[Notifications] FCM Token: $token');
        }
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('[Notifications] Token refreshed: $newToken');
        }
        _saveTokenToFirestore(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('[Notifications] Foreground message: ${message.notification?.title}');
        }
        // Handle notification when app is in foreground
        // You can show a local notification or update UI here
      });

      // Handle background messages (when app is in background but not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('[Notifications] Opened app from notification: ${message.notification?.title}');
        }
        // Navigate to specific screen based on notification data
        _handleNotificationTap(message);
      });

      // Check if app was launched from a notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('[Notifications] App launched from notification: ${initialMessage.notification?.title}');
        }
        _handleNotificationTap(initialMessage);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('[Notifications] Error initializing: $e');
      }
    }
  }

  /// Save FCM token to Firestore for the current user
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (kDebugMode) {
          print('[Notifications] Token saved to Firestore for user ${user.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Notifications] Error saving token to Firestore: $e');
      }
    }
  }

  /// Handle notification tap - navigate to appropriate screen
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    
    if (kDebugMode) {
      print('[Notifications] Handling tap - type: $type, data: $data');
    }
    
    // Add navigation logic based on notification type
    switch (type) {
      case 'activity_reminder':
      case 'activity_encouragement':
      case 'evening_reminder':
      case 'morning_reminder':
      case 'midday_reminder':
        // Navigate to activities page
        // You can implement this with Navigator or a global navigation key
        break;
      case 'achievement':
        // Navigate to progress/achievements page
        if (kDebugMode) {
          print('[Notifications] Achievement unlocked: ${data['icon']}');
        }
        break;
      case 'social_media_alert':
        // Navigate to digital wellbeing section
        break;
      default:
        // Default action
        break;
    }
  }

  /// Request notification permission (call this when user wants to enable notifications)
  static Future<bool> requestPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      if (kDebugMode) {
        print('[Notifications] Error requesting permission: $e');
      }
      return false;
    }
  }

  /// Delete FCM token when user signs out
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      if (kDebugMode) {
        print('[Notifications] Token deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Notifications] Error deleting token: $e');
      }
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('[Notifications] Background message: ${message.notification?.title}');
  }
  // Handle background notification here
}
