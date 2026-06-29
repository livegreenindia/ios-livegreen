import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Read an optional web client id passed via --dart-define=GOOGLE_CLIENT_ID=...
const _webGoogleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a cryptographically secure random nonce for Sign in with Apple.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Sign in using Apple (iOS). Required by App Store Guideline 4.8 whenever a
  /// third-party login such as Google is offered.
  Future<UserCredential> signInWithApple() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        // Use Firebase's signInWithProvider which presents via ASWebAuthenticationSession.
        // This is safe on iPad — avoids the UIPopoverPresentationController crash
        // that affects native ASAuthorizationController on iPad.
        final provider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        return await _auth.signInWithProvider(provider);
      }

      // Android / web fallback: use the sign_in_with_apple package with a nonce.
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple only returns the name on the very first authorization. Persist it
      // to the Firebase profile if we received one and none is set yet.
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((p) => p != null && p.isNotEmpty).join(' ');
      final user = userCredential.user;
      if (fullName.isNotEmpty &&
          user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(fullName);
        await user.reload();
      }
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw FirebaseAuthException(
        code: e.code == AuthorizationErrorCode.canceled
            ? 'sign_in_canceled'
            : 'apple_sign_in_failed',
        message: 'Apple sign in failed: ${e.message}',
      );
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      throw FirebaseAuthException(
        code: 'apple_sign_in_failed',
        message: 'Apple sign in failed: ${e.toString()}',
      );
    }
  }

  /// Permanently delete the signed-in user's account and associated data.
  /// Required by App Store Guideline 5.1.1(v).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to delete.',
      );
    }
    final uid = user.uid;

    // Best-effort removal of the user's Firestore document.
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    } catch (_) {
      // Non-fatal: continue with auth account deletion.
    }

    // Deleting the auth account may require a recent login; the caller surfaces
    // the 'requires-recent-login' error so the user can re-authenticate.
    await user.delete();

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // iOS: use Firebase's web OAuth flow (ASWebAuthenticationSession) to avoid
      // the UIPopoverPresentationController crash on iPad (SIGABRT / NSException).
      // Android: use native GIDSignIn for the account-picker sheet UX.
      if (!kIsWeb && Platform.isIOS) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        return await _auth.signInWithProvider(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw FirebaseAuthException(
            code: 'sign_in_canceled',
            message: 'Google sign in was canceled by the user',
          );
        }
        final googleAuth = await googleUser.authentication;
        return await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-canceled' ||
          e.code == 'canceled' ||
          e.code == 'user-cancelled') {
        throw FirebaseAuthException(
          code: 'sign_in_canceled',
          message: 'Google sign in was canceled by the user',
        );
      }
      rethrow;
    } catch (e) {
      if (e is FirebaseAuthException) rethrow;
      throw FirebaseAuthException(
        code: 'google_sign_in_failed',
        message: 'Google sign in failed: ${e.toString()}',
      );
    }
  }

  /// Sign in using Facebook. For now this calls FirebaseAuth.signInWithPopup on web and
  /// throws on platforms where the Facebook plugin isn't configured.
  Future<UserCredential> signInWithFacebook() async {
    // FirebaseAuth supports FacebookAuthProvider; web will open popup automatically
    final provider = FacebookAuthProvider();
    return await _auth.signInWithProvider(provider);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// Sign in using email & password
  Future<UserCredential> signInWithEmail({required String email, required String password}) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Create a new user using email & password
  Future<UserCredential> signUpWithEmail({required String email, required String password}) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /// Send password reset email
  Future<void> sendPasswordReset({required String email}) async {
    return await _auth.sendPasswordResetEmail(email: email);
  }

  /// Update the current user's display name
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user');
    await user.updateDisplayName(name);
    // reload to ensure changes are reflected locally
    await user.reload();
  }

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user');
    
    // Reload user data to get latest email verification status
    await user.reload();
    final refreshedUser = _auth.currentUser;
    
    if (refreshedUser != null && !refreshedUser.emailVerified) {
      await refreshedUser.sendEmailVerification();
    }
  }

  /// Check if current user's email is verified
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    // Reload to get latest verification status from server
    await user.reload();
    final refreshedUser = _auth.currentUser;
    return refreshedUser?.emailVerified ?? false;
  }

  /// Reload current user data from Firebase
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  /// Get current user with fresh data
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Development helper: when running locally against the Auth emulator,
  /// create or sign in a deterministic dev user so local API calls have a
  /// valid ID token. This avoids needing to complete the OAuth popup during
  /// automated local testing.
  Future<void> ensureSignedInForDev() async {
    final apiBase = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final isLocal = apiBase.contains('127.0.0.1') || apiBase.contains('localhost');
    if (!isLocal) return;
    final user = _auth.currentUser;
    if (user != null) return;

    const email = 'dev@local.test';
    const password = 'DevPass123!';
    try {
      // Try sign-in; if user doesn't exist, create then sign-in.
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      try {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } catch (err) {
        // Fallback to anonymous sign-in if email creation fails.
        await _auth.signInAnonymously();
      }
    }
  }
}
