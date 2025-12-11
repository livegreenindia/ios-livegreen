import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing user profile with realtime updates
class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Calculate current streak (consecutive days with at least 1 activity completed)
  static Future<int> calculateStreak() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      int streak = 0;
      DateTime checkDate = DateTime.now();

      // Check up to 365 days back
      for (int i = 0; i < 365; i++) {
        final dateStr =
            '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

        final completions = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('completions')
            .where('date', isEqualTo: dateStr)
            .limit(1)
            .get();

        if (completions.docs.isNotEmpty) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          // If today has no completions, check if streak started yesterday
          if (i == 0) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  /// Get total completed activities count
  static Future<int> getTotalCompletedActivities() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('completions')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting total completions: $e');
      return 0;
    }
  }

  /// Get average wellness score from last 7 days
  static Future<int> getAverageWellnessScore() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final startDateStr =
          '${sevenDaysAgo.year.toString().padLeft(4, '0')}-${sevenDaysAgo.month.toString().padLeft(2, '0')}-${sevenDaysAgo.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('happiness')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      int total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['score'] as int?) ?? 0;
      }

      // Convert to percentage (score is 1-10, so multiply by 10)
      return ((total / snapshot.docs.length) * 10).round();
    } catch (e) {
      debugPrint('Error getting wellness score: $e');
      return 0;
    }
  }

  /// Get all profile stats at once
  static Future<Map<String, dynamic>> getProfileStats() async {
    final results = await Future.wait([
      calculateStreak(),
      getTotalCompletedActivities(),
      getAverageWellnessScore(),
    ]);

    return {
      'streak': results[0],
      'completedActivities': results[1],
      'wellnessScore': results[2],
    };
  }

  /// Stream of profile data for the current user
  /// Returns null when user is not authenticated
  static Stream<Map<String, dynamic>?> profileStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            // Return basic profile from Firebase Auth if no Firestore document
            return {
              'uid': user.uid,
              'email': user.email,
              'name': user.displayName,
              'displayName': user.displayName,
              'photoURL': user.photoURL,
            };
          }

          final data = snapshot.data() ?? {};
          // Merge Firebase Auth data with Firestore data
          return {
            'uid': user.uid,
            'email': data['email'] ?? user.email,
            'name': data['name'] ?? data['displayName'] ?? user.displayName,
            'displayName':
                data['displayName'] ?? data['name'] ?? user.displayName,
            'photoURL': data['photoURL'] ?? user.photoURL,
            'plan': data['plan'] ?? 'Free',
            'premiumSince': data['premiumSince'],
            'streak': data['streak'] ?? 0,
            'completedActivities': data['completedActivities'] ?? 0,
            'wellnessScore': data['wellnessScore'] ?? 0,
            ...data, // Include all other fields from Firestore
          };
        })
        .handleError((error) {
          debugPrint('Profile stream error: $error');
          // Return basic auth data on error
          return {
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
          };
        });
  }

  /// Get current user's profile once (not realtime)
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();

      if (!snapshot.exists) {
        return {
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        };
      }

      final data = snapshot.data() ?? {};
      return {
        'uid': user.uid,
        'email': data['email'] ?? user.email,
        'name': data['name'] ?? data['displayName'] ?? user.displayName,
        'displayName': data['displayName'] ?? data['name'] ?? user.displayName,
        'photoURL': data['photoURL'] ?? user.photoURL,
        'plan': data['plan'] ?? 'Free',
        'premiumSince': data['premiumSince'],
        ...data,
      };
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return {
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      };
    }
  }

  /// Update user profile fields
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(user.uid).set({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Check if user has premium/supporter status
  static Future<bool> isPremium() async {
    final profile = await getProfile();
    return profile?['plan'] == 'Premium';
  }

  /// Stream to check premium status in realtime
  static Stream<bool> premiumStatusStream() {
    return profileStream().map((profile) => profile?['plan'] == 'Premium');
  }
}
