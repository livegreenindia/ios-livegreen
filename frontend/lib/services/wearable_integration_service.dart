import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/services.dart';

/// Minimal, non-invasive service to orchestrate wearable sync.
/// This file contains stubs and safe defaults. Replace TODOs with real values.

class WearableIntegrationService {
  // Singleton instance so multiple screens share the same service and stream
  static final WearableIntegrationService _instance = WearableIntegrationService._internal();
  factory WearableIntegrationService() => _instance;
  WearableIntegrationService._internal() {
    _ensureDefaultConfiguration();
  }

  // Broadcast stream for live data updates (fitbit + samsung payloads)
  final StreamController<Map<String, dynamic>> _dataStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Production backend URL (deployed Cloud Functions)
  static const String _defaultBackendBase = 'https://us-central1-livegreen-bf838.cloudfunctions.net/api';
  
  /// Ensures critical configuration is persisted in secure storage
  Future<void> _ensureDefaultConfiguration() async {
    try {
      // Ensure backend API base is always configured
      final existingBackend = await _secureStorage.read(key: 'backend_api_base');
      if (existingBackend == null || existingBackend.trim().isEmpty) {
        await _secureStorage.write(key: 'backend_api_base', value: _defaultBackendBase);
        debugPrint('Initialized backend_api_base in secure storage: $_defaultBackendBase');
      }
      
      // Ensure redirect URI has a default for mobile
      if (!kIsWeb) {
        final existingRedirect = await _secureStorage.read(key: 'fitbit_redirect_uri');
        if (existingRedirect == null || existingRedirect.trim().isEmpty) {
          const defaultRedirect = 'livegreen://auth';
          await _secureStorage.write(key: 'fitbit_redirect_uri', value: defaultRedirect);
          debugPrint('Initialized fitbit_redirect_uri in secure storage: $defaultRedirect');
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize default configuration: $e');
    }
  }

  // Progress callback: message, percentage (0.0-1.0), stepIndex, totalSteps
  void Function(String message, double percent, int step, int total)? progressCallback;
  // Data callback: provides fetched Fitbit and Samsung payloads as they become available
  void Function(Map<String, dynamic> fitbit, Map<String, dynamic> samsung)? dataCallback;

  bool _cancelRequested = false;

  void registerProgressCallback(void Function(String, double, int, int) cb) {
    progressCallback = cb;
  }

  void registerDataCallback(void Function(Map<String, dynamic>, Map<String, dynamic>) cb) {
    dataCallback = cb;
  }

  /// Save Fitbit client credentials into secure storage (used for development/admin).
  /// Do NOT hard-code secrets in source. Use this method from a secure admin UI.
  Future<void> saveFitbitCredentials({required String clientId, required String clientSecret, required String redirectUri}) async {
    await _secureStorage.write(key: 'fitbit_client_id', value: clientId);
    // Only persist client_secret when a non-empty value is provided. This
    // allows the Admin helper to pass an empty string in release builds
    // so the secret is not stored on-device.
    if (clientSecret.trim().isNotEmpty) {
      await _secureStorage.write(key: 'fitbit_client_secret', value: clientSecret);
    }
    await _secureStorage.write(key: 'fitbit_redirect_uri', value: redirectUri);
  }

  /// Read currently-configured Fitbit credentials. Returns null keys when missing.
  Future<Map<String, String?>> readFitbitCredentials() async {
    final clientId = await _secureStorage.read(key: 'fitbit_client_id');
    final clientSecret = await _secureStorage.read(key: 'fitbit_client_secret');
    final redirectUri = await _secureStorage.read(key: 'fitbit_redirect_uri');
    return {
      'client_id': clientId,
      'client_secret': clientSecret,
      'redirect_uri': redirectUri,
    };
  }

  /// Read optional backend API base (e.g. https://us-central1-<proj>.cloudfunctions.net/api)
  Future<String?> readBackendBase() async {
    return await _secureStorage.read(key: 'backend_api_base');
  }

  /// Save backend API base into secure storage
  Future<void> saveBackendBase(String base) async {
    await _secureStorage.write(key: 'backend_api_base', value: base);
  }

  void cancel() {
    _cancelRequested = true;
  }

  Future<void> startFullSync(String uid) async {
    _cancelRequested = false;
    final steps = [
      'Connecting to Fitbit',
      'Fetching activity data',
      'Uploading to cloud',
    ];

    int stepIndex = 0;
    _notify(steps[stepIndex], 0.0, stepIndex + 1, steps.length);

    // Fitbit connect & fetch - optimized for speed
    if (_cancelRequested) return;
    _notify('Connecting to Fitbit...', 0.1, 1, steps.length);
    try {
      final fitbitOk = await connectFitbit().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Connection timeout: Please check your internet connection and try again.'),
      );
      if (!fitbitOk) {
        throw Exception('Unable to connect to Fitbit. Please try again or check your settings.');
      }
    } catch (e) {
      final msg = e is Exception ? e.toString() : 'Fitbit connection error: Please try again.';
      _notify(msg, 0.0, 1, steps.length);
      rethrow;
    }

    if (_cancelRequested) return;
    _notify('Fetching your activity data...', 0.4, 2, steps.length);
    final fitbitData = await fetchFitbitData().timeout(
      const Duration(seconds: 20),
      onTimeout: () => <String, dynamic>{},
    );

    // Notify UI with fetched data immediately for faster feedback
    try {
      dataCallback?.call(fitbitData, {});
      _dataStreamController.add({'fitbit': fitbitData, 'samsung': {}});
    } catch (_) {}

    if (_cancelRequested) return;
    _notify('Saving your data securely...', 0.7, 3, steps.length);
    await uploadToFirebase(uid, fitbitData, {}).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Upload timeout: Please check your connection and try again.'),
    );

    if (_cancelRequested) return;
    _notify('Sync completed successfully! ✓', 1.0, steps.length, steps.length);
  }

  void _notify(String message, double percent, int step, int total) {
    try {
      progressCallback?.call(message, percent, step, total);
    } catch (_) {}
  }

  // ------------------ Fitbit flow (stubs) ------------------
  Future<bool> connectFitbit() async {
    // Implement a minimal OAuth flow using flutter_web_auth.
    // Expectation: caller has configured a redirect URI (custom scheme) and Fitbit app.
    // Read stored values. If a backend is configured the client_id is not
    // required on-device (server will hold it). Redirect URI is still
    // required so the app can receive the OAuth callback.
  final clientId = await _secureStorage.read(key: 'fitbit_client_id');
  String? redirectUri = await _secureStorage.read(key: 'fitbit_redirect_uri');
  String? backendBase = await _secureStorage.read(key: 'backend_api_base');
  
  // Fallback: ensure backend is configured (should already be set by _ensureDefaultConfiguration)
  if (backendBase == null || backendBase.trim().isEmpty) {
    backendBase = _defaultBackendBase;
    await _secureStorage.write(key: 'backend_api_base', value: _defaultBackendBase);
    debugPrint('Fallback: configured backend_api_base: $_defaultBackendBase');
  }

  // Debug: surface stored creds so we can diagnose missing-config issues quickly
  try {
    debugPrint('connectFitbit: stored client_id=${clientId ?? "<null>"}, redirect_uri=${redirectUri ?? "<null>"}, backend_base=$backendBase');
  } catch (_) {}

  if ((redirectUri ?? '').isEmpty) {
      // Developer convenience: if redirect URI is missing, auto-save a sensible
      // default depending on platform. For web, use the current origin so
      // flutter_web_auth can return to http(s)://localhost:xxxxx/ during local
      // testing. For mobile, use the custom scheme that the app registers.
      final String autoRedirect;
      if (kIsWeb) {
        // Use the current base URI for web (includes path). Ensure this exact
        // URL is registered in the Fitbit developer console as a redirect URL.
        autoRedirect = Uri.base.toString();
      } else {
        autoRedirect = 'livegreen://auth';
      }
      // For mobile we persist the default custom-scheme redirect. For web we
      // avoid persisting Uri.base automatically because the Fitbit app's
      // registered redirect URI must match exactly. Persisting a local
      // origin (e.g. http://localhost:xxxx/) can cause Fitbit to reject the
      // authorize request if that origin isn't registered in the developer
      // console. Instead keep the redirect in-memory for this run and prompt
      // the developer to save the correct redirect via the Admin screen.
      redirectUri = autoRedirect;
      if (!kIsWeb) {
        try {
          await _secureStorage.write(key: 'fitbit_redirect_uri', value: autoRedirect);
          _notify('Redirect URI missing — auto-saved default $autoRedirect. Open Admin to change.', 0.0, 1, 5);
        } catch (e) {
          _notify('Redirect URI set to $autoRedirect (persistence failed: ${e.toString()}). Open Admin to save.', 0.0, 1, 5);
        }
      } else {
        // Web: do not overwrite stored redirect automatically. Tell the dev to
        // update the Admin screen or register the origin in Fitbit console.
        _notify('Using temporary redirect URI $autoRedirect for this run.\nEnsure this exact URL is registered in the Fitbit developer console and save it via Admin to persist.', 0.0, 1, 5);
      }
    }

    // Validate configuration: either a client_id must be present for on-device PKCE
    // or a backend must be configured to perform confidential exchanges.
    // Since we now auto-configure backend, this check is mainly for client_id when needed.
    if ((clientId == null || clientId.isEmpty) && backendBase.isEmpty) {
      final msg = 'Setup required: Fitbit connection not configured.\nPlease contact support for assistance.';
      _notify(msg, 0.0, 1, 5);
      throw Exception(msg);
    }

    // Ensure redirectUri is available (should have been auto-saved above for dev). If missing, provide guidance.
    if (redirectUri == null || redirectUri.isEmpty) {
      final msg = 'Configuration error: Unable to complete setup.\nPlease try again or contact support.';
      _notify(msg, 0.0, 1, 5);
      throw Exception(msg);
    }

    // If we already have a token, accept it (could validate expiry)
  final token = await _secureStorage.read(key: 'fitbit_access_token');
  if (token != null) return true;

  // Use PKCE: generate a code_verifier and code_challenge; store verifier locally until exchange.
  final clientSecret = await _secureStorage.read(key: 'fitbit_client_secret');
  final codeVerifier = _generateCodeVerifier();
  final codeChallenge = _codeChallenge(codeVerifier);
  await _secureStorage.write(key: 'fitbit_pkce_verifier', value: codeVerifier);

  // If a backend is configured, ask it to construct the authorize URL so the
  // mobile client doesn't need to carry the client_id. Backend will also
  // persist a PKCE code_verifier per-user to be used during exchange.

  if (backendBase.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final idToken = user == null ? null : await user.getIdToken();
        final resp = await http.post(
          Uri.parse('$backendBase/fitbit/start'),
          headers: {
            'Content-Type': 'application/json',
            if (idToken != null) 'Authorization': 'Bearer $idToken',
          },
          body: json.encode({'redirect_uri': redirectUri}),
        ).timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final bodyJson = json.decode(resp.body) as Map<String, dynamic>;
          final authorizeUrl = bodyJson['authorize_url'] as String? ?? bodyJson['authorize_url'];
          if (authorizeUrl == null) {
            final msg = 'Backend did not return authorize_url';
            _notify(msg, 0.0, 1, 5);
            throw Exception(msg);
          }

          // Debug: show the full authorize URL the app will open
          try { debugPrint('authorizeUrl (backend): $authorizeUrl'); } catch (_) {}

          // Launch the backend-provided URL which already includes PKCE challenge
          final result = await FlutterWebAuth2.authenticate(url: authorizeUrl, callbackUrlScheme: Uri.parse(redirectUri).scheme);
          final uri = Uri.parse(result);
          final code = uri.queryParameters['code'];
          if (code == null) {
            final msg = 'Authorization cancelled: Please approve access to sync your Fitbit data.';
            _notify(msg, 0.0, 1, 5);
            throw Exception(msg);
          }

          // Now tell backend to exchange code; backend will use its stored verifier.
          final exch = await _withRetry(() => http.post(Uri.parse('$backendBase/fitbit/exchange'),
            headers: {
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: json.encode({'code': code, 'redirect_uri': redirectUri}),
          ).timeout(const Duration(seconds: 15)), retryOnStatus: [429], maxAttempts: 4);

          if (exch.statusCode == 200) {
            final bodyJson2 = json.decode(exch.body) as Map<String, dynamic>;
            final tokenPayload = bodyJson2['token'] as Map<String, dynamic>? ?? bodyJson2;
            if (tokenPayload['access_token'] != null) {
              await _secureStorage.write(key: 'fitbit_access_token', value: tokenPayload['access_token'] as String);
            }
            if (tokenPayload['refresh_token'] != null) {
              await _secureStorage.write(key: 'fitbit_refresh_token', value: tokenPayload['refresh_token'] as String);
            }
            // clear any client-side verifier if present
            await _secureStorage.delete(key: 'fitbit_pkce_verifier');
            return true;
          } else {
            final msg = 'Backend exchange failed (status ${exch.statusCode})';
            _notify(msg, 0.0, 1, 5);
            // fallthrough to client-side fallback below
          }
        } else {
          _notify('Backend start failed (status ${resp.statusCode})', 0.0, 1, 5);
        }
      } catch (e) {
        _notify('Backend start error: ${e.toString()}', 0.0, 1, 5);
        // fallthrough to client-side flow
      }
    }

  // If backend not configured or exchange failed, fall back to previous client-side flow.
  try {
      // Build the authorize URL with PKCE
      final authParams = {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': 'activity heartrate sleep profile',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      };

  final authUrl = Uri.https('www.fitbit.com', '/oauth2/authorize', authParams);
  try { debugPrint('authorizeUrl (pkce): ${authUrl.toString()}'); } catch (_) {}

  final result = await FlutterWebAuth2.authenticate(url: authUrl.toString(), callbackUrlScheme: Uri.parse(redirectUri).scheme);
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      if (code == null) {
        final msg = 'Authorization cancelled: Please approve access to sync your Fitbit data.';
        _notify(msg, 0.0, 1, 5);
        throw Exception(msg);
      }

      // Fallback: in release builds we require a backend. Do not allow
      // confidential or PKCE exchanges on-device in production.
      final storedVerifierVal = await _secureStorage.read(key: 'fitbit_pkce_verifier');
      if (kReleaseMode) {
        final msg = 'Production builds must use a server-backed OAuth flow. Configure backend_api_base and deploy server-side token exchange.';
        _notify(msg, 0.0, 1, 5);
        throw Exception(msg);
      }

      // Development mode: if a client secret is present on-device, perform a
      // confidential exchange (dev-only convenience). Otherwise use PKCE-only exchange.
      if (clientSecret != null && clientSecret.isNotEmpty) {
        // Confidential exchange using HTTP Basic auth (client_id:client_secret)
        if (clientId == null || clientId.isEmpty) {
          final msg = 'client_id required for confidential on-device flow';
          _notify(msg, 0.0, 1, 5);
          throw Exception(msg);
        }

        final authBasic = base64Url.encode(utf8.encode('$clientId:$clientSecret'));
        final headers = {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $authBasic',
        };
        final body = 'code=${Uri.encodeComponent(code)}&grant_type=authorization_code&redirect_uri=${Uri.encodeComponent(redirectUri)}';

  final tokenResp = await _withRetry(() => http.post(Uri.parse('https://api.fitbit.com/oauth2/token'), headers: headers, body: body).timeout(const Duration(seconds: 15)), retryOnStatus: [429], maxAttempts: 4);

  try { debugPrint('token endpoint response (confidential): status=${tokenResp.statusCode} body=${tokenResp.body}'); } catch (_) {}

        if (tokenResp.statusCode == 200) {
          final bodyJson = json.decode(tokenResp.body) as Map<String, dynamic>;
          await _secureStorage.write(key: 'fitbit_access_token', value: bodyJson['access_token'] as String?);
          if (bodyJson['refresh_token'] != null) {
            await _secureStorage.write(key: 'fitbit_refresh_token', value: bodyJson['refresh_token'] as String);
          }
          // clear verifier after use (if any)
          await _secureStorage.delete(key: 'fitbit_pkce_verifier');
          // For production safety: remove client_secret from device after successful confidential exchange
          try { await _secureStorage.delete(key: 'fitbit_client_secret'); } catch (_) {}
          // store expires_at if provided
          if (bodyJson['expires_in'] != null) {
            final expiresIn = (bodyJson['expires_in'] as num).toInt();
            final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
            await _secureStorage.write(key: 'fitbit_access_expires_at', value: expiresAt.toIso8601String());
          }
          return true;
        } else {
          final msg = 'Confidential token exchange failed (status ${tokenResp.statusCode})';
          _notify(msg, 0.0, 1, 5);
          throw Exception(msg);
        }
      }

      // PKCE flow: include client_id and code_verifier
      if (clientId == null || clientId.isEmpty) {
        final msg = 'client_id required for PKCE on-device flow';
        _notify(msg, 0.0, 1, 5);
        throw Exception(msg);
      }

      final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
      final body = 'code=${Uri.encodeComponent(code)}&grant_type=authorization_code&redirect_uri=${Uri.encodeComponent(redirectUri)}&client_id=${Uri.encodeComponent(clientId)}&code_verifier=${Uri.encodeComponent(storedVerifierVal ?? '')}';

  final tokenResp = await _withRetry(() => http.post(Uri.parse('https://api.fitbit.com/oauth2/token'), headers: headers, body: body).timeout(const Duration(seconds: 15)), retryOnStatus: [429], maxAttempts: 4);

  try { debugPrint('token endpoint response (pkce): status=${tokenResp.statusCode} body=${tokenResp.body}'); } catch (_) {}

      if (tokenResp.statusCode == 200) {
        final bodyJson = json.decode(tokenResp.body) as Map<String, dynamic>;
        await _secureStorage.write(key: 'fitbit_access_token', value: bodyJson['access_token'] as String?);
        if (bodyJson['refresh_token'] != null) {
          await _secureStorage.write(key: 'fitbit_refresh_token', value: bodyJson['refresh_token'] as String);
        }
        // clear verifier after use
        await _secureStorage.delete(key: 'fitbit_pkce_verifier');
        // store expires_at if provided
        if (bodyJson['expires_in'] != null) {
          final expiresIn = (bodyJson['expires_in'] as num).toInt();
          final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
          await _secureStorage.write(key: 'fitbit_access_expires_at', value: expiresAt.toIso8601String());
        }
        return true;
      } else {
        final msg = 'Token exchange failed (status ${tokenResp.statusCode})';
        _notify(msg, 0.0, 1, 5);
        throw Exception(msg);
      }
    } catch (e) {
      final msg = 'Fitbit connect error: ${e.toString()}';
      _notify(msg, 0.0, 1, 5);
      throw Exception(msg);
    }
  }

  // Generic retry wrapper with exponential backoff and jitter. retriable on network errors or configured statuses (e.g. 429)
  Future<T> _withRetry<T>(Future<T> Function() fn, {List<int> retryOnStatus = const [], int maxAttempts = 3, Duration baseDelay = const Duration(seconds:1)}) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final res = await fn();
        // If response-like object with statusCode check retryOnStatus
        if (res is http.Response && retryOnStatus.contains(res.statusCode) && attempt < maxAttempts) {
          final retryAfter = res.headers['retry-after'];
          int waitMs = baseDelay.inMilliseconds * (1 << (attempt - 1));
          if (retryAfter != null) {
            final parsed = int.tryParse(retryAfter);
            if (parsed != null) waitMs = parsed * 1000;
          }
          // add jitter
          final jitter = Random().nextInt(300);
          await Future.delayed(Duration(milliseconds: waitMs + jitter));
          continue;
        }
        return res;
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        final waitMs = baseDelay.inMilliseconds * (1 << (attempt - 1)) + Random().nextInt(300);
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }
  }

  String _generateCodeVerifier([int length = 64]) {
    // length between 43 and 128
    final rng = Random.secure();
    final bytes = List<int>.generate(length, (_) => rng.nextInt(256));
    // base64url without padding
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final bytes = sha256.convert(utf8.encode(verifier)).bytes;
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<Map<String, dynamic>> fetchFitbitData() async {
    // Attempt to read cached token and call Fitbit APIs
    final token = await _secureStorage.read(key: 'fitbit_access_token');
    if (token == null) {
      _notify('No Fitbit access token found. Please connect your Fitbit device.', 0.0, 2, 5);
      return {};
    }

    // If token has an expires_at, refresh a bit before expiry
    final expiresAtStr = await _secureStorage.read(key: 'fitbit_access_expires_at');
    if (expiresAtStr != null) {
      try {
        final expiresAt = DateTime.parse(expiresAtStr).toUtc();
        final now = DateTime.now().toUtc();
        // If token expires within next 60 seconds, attempt refresh
        if (expiresAt.difference(now).inSeconds <= 60) {
          _notify('Refreshing Fitbit access token...', 0.15, 2, 5);
          final refreshed = await _refreshFitbitToken();
          if (refreshed) {
            final newToken = await _secureStorage.read(key: 'fitbit_access_token');
            if (newToken != null) return await fetchFitbitData();
          }
        }
      } catch (_) {}
    }

    // Fetch comprehensive Fitbit data: steps, calories, distance, heart rate, activities
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final headers = { 'Authorization': 'Bearer $token' };
    
    try {
      final results = <String, dynamic>{};
      
      // Fetch steps
      _notify('Fetching steps data...', 0.2, 2, 5);
      try {
        final stepsResp = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$today/1d.json'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        if (stepsResp.statusCode == 200) {
          results['fitbit_steps_payload'] = json.decode(stepsResp.body);
        } else if (stepsResp.statusCode == 401) {
          await _refreshFitbitToken();
          return await fetchFitbitData();
        }
      } catch (e) {
        debugPrint('Failed to fetch steps: $e');
      }

      // Fetch calories
      _notify('Fetching calories data...', 0.3, 2, 5);
      try {
        final caloriesResp = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/calories/date/$today/1d.json'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        if (caloriesResp.statusCode == 200) {
          results['fitbit_calories_payload'] = json.decode(caloriesResp.body);
        }
      } catch (e) {
        debugPrint('Failed to fetch calories: $e');
      }

      // Fetch distance
      _notify('Fetching distance data...', 0.4, 2, 5);
      try {
        final distanceResp = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/distance/date/$today/1d.json'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        if (distanceResp.statusCode == 200) {
          results['fitbit_distance_payload'] = json.decode(distanceResp.body);
        }
      } catch (e) {
        debugPrint('Failed to fetch distance: $e');
      }

      // Fetch heart rate
      _notify('Fetching heart rate data...', 0.5, 2, 5);
      try {
        final heartResp = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/$today/1d.json'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        if (heartResp.statusCode == 200) {
          results['fitbit_heart_payload'] = json.decode(heartResp.body);
        }
      } catch (e) {
        debugPrint('Failed to fetch heart rate: $e');
      }

      // Fetch activities summary
      _notify('Fetching activity summary...', 0.6, 2, 5);
      try {
        final activityResp = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/date/$today.json'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        if (activityResp.statusCode == 200) {
          results['fitbit_activity_summary'] = json.decode(activityResp.body);
        }
      } catch (e) {
        debugPrint('Failed to fetch activity summary: $e');
      }

      if (results.isEmpty) {
        _notify('Unable to fetch Fitbit data. Please check your connection and try again.', 0.0, 2, 5);
      } else {
        _notify('Fitbit data retrieved successfully!', 0.7, 2, 5);
      }
      
      return results;
    } catch (e) {
      _notify('Error fetching Fitbit data: ${e.toString()}', 0.0, 2, 5);
      return {};
    }
  }

  Future<bool> _refreshFitbitToken() async {
    final refresh = await _secureStorage.read(key: 'fitbit_refresh_token');
    final backendBase = await _secureStorage.read(key: 'backend_api_base');
    if (refresh == null) return false;

    try {
      // Prefer server-side refresh if backend configured
      if (backendBase != null && backendBase.isNotEmpty) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final idToken = user == null ? null : await user.getIdToken();
          final resp = await _withRetry(() => http.post(
            Uri.parse('$backendBase/fitbit/refresh'),
            headers: {
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: json.encode({}), // server will use stored refresh token for user
          ).timeout(const Duration(seconds: 15)), retryOnStatus: [429], maxAttempts: 4);

          if (resp.statusCode == 200) {
            final body = json.decode(resp.body) as Map<String, dynamic>;
            final tokenPayload = body['token'] as Map<String, dynamic>? ?? body;
            if (tokenPayload['access_token'] != null) {
              await _secureStorage.write(key: 'fitbit_access_token', value: tokenPayload['access_token'] as String);
            }
            if (tokenPayload['refresh_token'] != null) {
              await _secureStorage.write(key: 'fitbit_refresh_token', value: tokenPayload['refresh_token'] as String);
            }
            if (tokenPayload['expires_in'] != null) {
              final expiresIn = (tokenPayload['expires_in'] as num).toInt();
              final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
              await _secureStorage.write(key: 'fitbit_access_expires_at', value: expiresAt.toIso8601String());
            }
            return true;
          }
        } catch (e) {
          return false;
        }
      }

      // If no backend configured, do NOT perform confidential refresh on-device. Ask user to configure backend.
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Test connection state: checks backend reachability and token presence/expiry.
  Future<Map<String, dynamic>> testConnection() async {
    final backendBase = await readBackendBase();
    final redirect = await _secureStorage.read(key: 'fitbit_redirect_uri');
    final clientId = await _secureStorage.read(key: 'fitbit_client_id');
    final hasAccess = (await _secureStorage.read(key: 'fitbit_access_token')) != null;
    final expiresAt = await _secureStorage.read(key: 'fitbit_access_expires_at');
    final result = <String, dynamic>{
      'backend_base': backendBase,
      'redirect_uri': redirect,
      'client_id': clientId,
      'has_access_token': hasAccess,
      'access_expires_at': expiresAt
    };
    if (backendBase != null && backendBase.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final idToken = user == null ? null : await user.getIdToken();
        final resp = await _withRetry(() => http.post(Uri.parse('$backendBase/fitbit/start'), headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken'
        }, body: json.encode({'redirect_uri': redirect})).timeout(const Duration(seconds: 8)), retryOnStatus: [429], maxAttempts: 2);
        result['backend_ok'] = resp.statusCode == 200;
      } catch (e) {
        result['backend_ok'] = false;
        result['backend_error'] = e.toString();
      }
    }
    return result;
  }

  // ------------------ Samsung Health flow (stubs) ------------------
  Future<bool> connectSamsungHealth() async {
    // Call into native Android code via MethodChannel to initialize / request permissions
    const channel = MethodChannel('livegreen/samsung_health');
    try {
      final res = await channel.invokeMethod<bool>('connect');
      return res == true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchSamsungData() async {
    const channel = MethodChannel('livegreen/samsung_health');
    try {
      final map = await channel.invokeMethod<Map>('fetchData');
      if (map == null) return {};
      return Map<String, dynamic>.from(map);
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
  }

  Future<void> uploadToFirebase(String uid, Map<String, dynamic> fitbit, Map<String, dynamic> samsung) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    // daily_metrics doc
    final dailyRef = _firestore.collection('daily_metrics').doc('$uid:${now.toIso8601String().substring(0,10)}');
    batch.set(dailyRef, {
      'uid': uid,
      'date': now.toIso8601String().substring(0,10),
      'fitbit': fitbit,
      'samsung': samsung,
      'last_updated': now,
    });

    // activities collection (merge activity logs if present)
    if (fitbit['activities'] != null) {
      for (final a in (fitbit['activities'] as List<dynamic>)) {
        final doc = _firestore.collection('activities').doc();
        batch.set(doc, {
          'uid': uid,
          'source': 'fitbit',
          'payload': a,
          'created_at': now,
        });
      }
    }

    // commit
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // Provide clearer feedback for permission / rules failures
      final msg = 'Unable to save your data. Please check your connection and try again.';
      _notify(msg, 0.0, 5, 5);
      try {
        debugPrint('uploadToFirebase FirebaseException: ${e.code} ${e.message}');
      } catch (_) {}
      throw Exception(msg);
    } catch (e) {
      final msg = 'Unable to save your activity data. Please try again.';
      _notify(msg, 0.0, 5, 5);
      try {
        debugPrint('uploadToFirebase unknown error: ${e.toString()}');
      } catch (_) {}
      throw Exception(msg);
    }

    // update user metadata
    final userRef = _firestore.collection('users').doc(uid);
    try {
      await userRef.set({'last_sync': now}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      // Non-critical error, log but don't throw
      try {
        debugPrint('Failed to update user metadata: ${e.code} ${e.message}');
      } catch (_) {}
    } catch (e) {
      // Non-critical error, log but don't throw
      try {
        debugPrint('Failed to update user metadata: ${e.toString()}');
      } catch (_) {}
    }
  }

  /// Debug helper: run full sync and capture/print any errors (message + stack)
  /// Returns a map with keys: ok (bool), error (optional), stack (optional)
  Future<Map<String, dynamic>> debugRunFullSync(String uid) async {
    try {
      // capture current stored config for debugging
      final creds = await readFitbitCredentials();
      final backend = await readBackendBase();
      debugPrint('debugRunFullSync: stored creds=${{ 'client_id': creds['client_id'], 'redirect_uri': creds['redirect_uri'], 'has_client_secret': creds['client_secret'] != null && creds['client_secret']!.isNotEmpty }}');
      debugPrint('debugRunFullSync: backend_base=$backend');

      await startFullSync(uid);
      debugPrint('debugRunFullSync: completed successfully for uid=$uid');
      return {'ok': true, 'stored': {'client_id': creds['client_id'], 'has_client_secret': creds['client_secret'] != null && creds['client_secret']!.isNotEmpty, 'redirect_uri': creds['redirect_uri'], 'backend_base': backend}};
    } catch (e, st) {
      final errMsg = e is Exception ? e.toString() : e.toString();
      debugPrint('debugRunFullSync -> error: $errMsg\n$st');
      // also include stored config to help diagnose missing credentials
      try {
        final creds = await readFitbitCredentials();
        final backend = await readBackendBase();
        _notify('Debug sync failed: $errMsg', 0.0, 1, 5);
        return {
          'ok': false,
          'error': errMsg,
          'stack': st.toString(),
          'stored': {
            'client_id': creds['client_id'],
            'has_client_secret': creds['client_secret'] != null && creds['client_secret']!.isNotEmpty,
            'redirect_uri': creds['redirect_uri'],
            'backend_base': backend
          }
        };
      } catch (_) {
        _notify('Debug sync failed: $errMsg', 0.0, 1, 5);
        return {'ok': false, 'error': errMsg, 'stack': st.toString()};
      }
    }
  }
}
