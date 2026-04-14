import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The number of free trial days before the subscription gate kicks in.
const int kTrialDays = 60;

/// Manages subscription/trial state for the app.
///
/// Sources of truth (priority order):
///   1. Firestore `users/{uid}.plan == 'Premium'`  — authoritative server state
///   2. SharedPreferences `is_premium`             — local optimistic cache
///   3. Firebase Auth `creationTime`               — trial start anchor
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _isPremium = false;
  bool _isLoading = true;
  DateTime? _accountCreatedAt;

  // ── Public state ────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isPremium => _isPremium;

  /// Days elapsed since account was created (0 if unknown).
  int get daysElapsed {
    if (_accountCreatedAt == null) return 0;
    return DateTime.now().difference(_accountCreatedAt!).inDays;
  }

  /// Days remaining in the free trial (0 if expired).
  int get daysLeft => math.max(0, kTrialDays - daysElapsed);

  /// True while the 60-day trial window is still open (and user is not premium).
  bool get isTrialActive => daysElapsed < kTrialDays && !_isPremium;

  /// True once the trial has expired and the user has not subscribed.
  bool get isTrialExpired => daysElapsed >= kTrialDays && !_isPremium;

  /// Whether gated content (Activities list, Clubs) should be blurred/locked.
  bool get shouldGate => isTrialExpired;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Call once from main when the user is authenticated.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadAccountCreationDate();
      await _loadPremiumStatus();
    } catch (e) {
      debugPrint('[SubscriptionService] init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force-refresh (e.g., after returning from the payment screen).
  Future<void> refresh() async {
    await initialize();
  }

  /// Optimistically mark premium (called after successful local payment).
  Future<void> markPremiumLocally() async {
    _isPremium = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
    } catch (_) {}
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _loadAccountCreationDate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final creationTime = user.metadata.creationTime;
      if (creationTime != null) {
        _accountCreatedAt = creationTime;
        return;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] error reading creationTime: $e');
    }

    // Firestore fallback: read createdAt stored during profile setup
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 6));

      final ts = doc.data()?['createdAt'];
      if (ts is Timestamp) {
        _accountCreatedAt = ts.toDate();
      }
    } catch (e) {
      debugPrint('[SubscriptionService] error reading Firestore createdAt: $e');
    }
  }

  Future<void> _loadPremiumStatus() async {
    // 1. Fast local check
    try {
      final prefs = await SharedPreferences.getInstance();
      final localPremium = prefs.getBool('is_premium') ?? false;
      if (localPremium) {
        _isPremium = true;
        // Still verify from Firestore in background
        _verifyPremiumFromFirestore();
        return;
      }
    } catch (_) {}

    // 2. Firestore authoritative check
    await _verifyPremiumFromFirestore();
  }

  Future<void> _verifyPremiumFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 6));

      final plan = doc.data()?['plan'] as String?;
      final firestorePremium = plan == 'Premium';

      if (firestorePremium != _isPremium) {
        _isPremium = firestorePremium;
        // Sync to local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_premium', firestorePremium);
        // Notify if something changed
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Firestore premium check failed: $e');
    }
  }
}
