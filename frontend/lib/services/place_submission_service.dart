import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/trek.dart';

/// Service for managing user-submitted places with admin approval
class PlaceSubmissionService {
  static final PlaceSubmissionService _instance = PlaceSubmissionService._internal();
  factory PlaceSubmissionService() => _instance;
  PlaceSubmissionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _treksCollection =>
      _firestore.collection('treks');

  CollectionReference<Map<String, dynamic>> get _pendingPlacesCollection =>
      _firestore.collection('pendingPlaces');

  /// Submit a new place for admin approval
  Future<String> submitPlace({
    required String title,
    required String description,
    required TrekCategory category,
    required double latitude,
    required double longitude,
    String? address,
    String? phoneNumber,
    String? website,
    String? imageUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final startPoint = GeoPoint(latitude: latitude, longitude: longitude);
    final location = TrekLocation.fromGeoPoint(startPoint);

    final placeData = {
      'title': title,
      'description': description,
      'category': category.name,
      'startPoint': startPoint.toMap(),
      'location': location.toMap(),
      'address': address,
      'phoneNumber': phoneNumber,
      'website': website,
      'imageUrl': imageUrl,
      'distance': 0.0,
      'estimatedTimeMinutes': 0,
      'difficulty': TrekDifficulty.easy.name,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': user.uid,
      'isPublic': false, // Not public until approved
      'isUserSubmitted': true,
      'approvalStatus': PlaceApprovalStatus.pending.name,
      'submitterName': user.displayName ?? user.email ?? 'Anonymous',
      'tags': [],
      'routePoints': [],
      'elevationProfile': [],
      'usersToday': 0,
      'rating': 0.0,
      'reviewCount': 0,
    };

    // Add to pending places collection for admin review
    final docRef = await _pendingPlacesCollection.add(placeData);
    
    debugPrint('Place submitted for approval: ${docRef.id}');
    return docRef.id;
  }

  /// Get all pending places (for admin)
  Stream<List<Trek>> streamPendingPlaces() {
    return _pendingPlacesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Trek.fromMap(data, doc.id);
      }).toList();
    });
  }

  /// Get pending places count (for admin badge)
  Stream<int> streamPendingCount() {
    return _pendingPlacesCollection.snapshots().map((s) => s.docs.length);
  }

  /// Approve a pending place (admin only)
  Future<void> approvePlace(String pendingPlaceId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get the pending place data
    final pendingDoc = await _pendingPlacesCollection.doc(pendingPlaceId).get();
    if (!pendingDoc.exists) throw Exception('Pending place not found');

    final data = pendingDoc.data()!;
    final now = DateTime.now();

    // Update with approval info
    data['isPublic'] = true;
    data['approvalStatus'] = PlaceApprovalStatus.approved.name;
    data['approvedBy'] = user.uid;
    data['approvedAt'] = now;
    data['updatedAt'] = now;

    // Move to main treks collection
    await _treksCollection.add(data);

    // Delete from pending collection
    await _pendingPlacesCollection.doc(pendingPlaceId).delete();

    debugPrint('Place approved and moved to treks: $pendingPlaceId');
  }

  /// Reject a pending place (admin only)
  Future<void> rejectPlace(String pendingPlaceId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final now = DateTime.now();

    await _pendingPlacesCollection.doc(pendingPlaceId).update({
      'approvalStatus': PlaceApprovalStatus.rejected.name,
      'rejectionReason': reason,
      'approvedBy': user.uid,
      'approvedAt': now,
      'updatedAt': now,
    });

    // Optionally delete after some time or notify user
    // For now, keep it for reference
    debugPrint('Place rejected: $pendingPlaceId');
  }

  /// Delete a rejected place
  Future<void> deletePendingPlace(String pendingPlaceId) async {
    await _pendingPlacesCollection.doc(pendingPlaceId).delete();
  }

  /// Get user's submitted places
  Stream<List<Trek>> streamUserSubmissions() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _pendingPlacesCollection
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Trek.fromMap(data, doc.id);
      }).toList();
    });
  }

  /// Check if user is admin
  Future<bool> isUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Check custom claims
      final idTokenResult = await user.getIdTokenResult();
      if (idTokenResult.claims?['admin'] == true) return true;

      // Also check Firestore user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['isAdmin'] == true || data?['role'] == 'admin';
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }

    return false;
  }
}
