import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription? _sub;

  /// Initialize deep link handling
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // Handle initial link (when app is opened from a link while closed)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri, navigatorKey);
      }
    } catch (e) {
      debugPrint('[DeepLink] Error getting initial URI: $e');
    }

    // Listen for links while app is running
    _sub = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri, navigatorKey);
      },
      onError: (err) {
        debugPrint('[DeepLink] Error: $err');
      },
    );
  }

  /// Handle deep link navigation
  static void _handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    debugPrint('[DeepLink] Received: $uri');

    // Handle club links: https://livegreen.app/clubs/{clubId}
    if ((uri.host == 'livegreen.app' || uri.host == 'clubs') && 
        uri.pathSegments.isNotEmpty && 
        uri.pathSegments.first == 'clubs') {
      
      if (uri.pathSegments.length >= 2) {
        final clubId = uri.pathSegments[1];
        debugPrint('[DeepLink] Navigating to club: $clubId');
        
        // Navigate to club details
        navigatorKey.currentState?.pushNamed(
          '/clubDetails',
          arguments: clubId,
        );
      }
    }
    // Handle auth callback
    else if (uri.host == 'auth') {
      debugPrint('[DeepLink] Auth callback');
      // Auth is already handled by flutter_web_auth_2
    }
  }

  /// Dispose of the stream subscription
  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
