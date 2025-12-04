import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Read an optional web client id passed via --dart-define=GOOGLE_CLIENT_ID=...
const _webGoogleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in using Google (works for mobile and web via the google_sign_in package)
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Initialize GoogleSignIn with minimal scopes
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: kIsWeb && _webGoogleClientId.isNotEmpty ? _webGoogleClientId : null,
      );

      // Attempt to sign in
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign_in_canceled',
          message: 'Google sign in was canceled by the user',
        );
      }

      // Get auth details
      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null) {
        throw FirebaseAuthException(
          code: 'missing_access_token',
          message: 'No access token received from Google',
        );
      }

      // Create and use Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      return await _auth.signInWithCredential(credential);
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
