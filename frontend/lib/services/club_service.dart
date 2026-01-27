import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new club (pending approval)
  Future<String> createClub({
    required String name,
    required String description,
    required ClubCategory category,
    required String location,
    required String creatorName,
    String? creatorImageUrl,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<String>? tags,
    String? website,
    String? contactEmail,
    String? phoneNumber,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final club = Club(
        id: '', // Will be set by Firestore
        name: name,
        description: description,
        imageUrl: imageUrl,
        category: category,
        status: ClubStatus.pending,
        creatorId: userId,
        creatorName: creatorName,
        creatorImageUrl: creatorImageUrl,
        leaderIds: [userId],
        memberIds: [userId],
        location: location,
        latitude: latitude,
        longitude: longitude,
        memberCount: 1,
        createdAt: DateTime.now(),
        activityCount: 0,
        tags: tags ?? [],
        website: website,
        contactEmail: contactEmail,
        phoneNumber: phoneNumber,
      );

      final docRef = await _firestore.collection('clubs').add(club.toFirestore());
      
      // Create member document for the creator in the members subcollection
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      await _firestore.collection('clubs').doc(docRef.id).collection('members').doc(userId).set({
        'clubId': docRef.id,
        'name': userData?['name'] ?? creatorName,
        'imageUrl': userData?['profileImageUrl'] ?? creatorImageUrl,
        'role': 'leader',
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create club: $e');
    }
  }

  // Get all approved clubs
  Future<List<Club>> getApprovedClubs({
    ClubCategory? category,
    String? searchQuery,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection('clubs').where('status', isEqualTo: 'approved');

      if (category != null) {
        query = query.where('category', isEqualTo: category.toString().split('.').last);
      }

      final snapshot = await query.limit(limit).get();
      final clubs = snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        return clubs
            .where((club) =>
                club.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                club.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
                club.tags.any((tag) => tag.toLowerCase().contains(searchQuery.toLowerCase())))
            .toList();
      }

      return clubs;
    } catch (e) {
      throw Exception('Failed to fetch approved clubs: $e');
    }
  }

  // Get pending clubs (for admin)
  Future<List<Club>> getPendingClubs({int limit = 50}) async {
    try {
      final snapshot =
          await _firestore.collection('clubs').where('status', isEqualTo: 'pending').limit(limit).get();
      return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending clubs: $e');
    }
  }

  // Get club by ID
  Future<Club?> getClubById(String clubId) async {
    try {
      final doc = await _firestore.collection('clubs').doc(clubId).get();
      return doc.exists ? Club.fromFirestore(doc) : null;
    } catch (e) {
      throw Exception('Failed to fetch club: $e');
    }
  }

  // Get user's clubs (created, leading, or member of)
  Future<List<Club>> getUserClubs() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('clubs')
          .where('status', isEqualTo: 'approved')
          .where('memberIds', arrayContains: userId)
          .get();

      return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch user clubs: $e');
    }
  }

  // Get clubs created by user
  Future<List<Club>> getCreatedClubs() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore.collection('clubs').where('creatorId', isEqualTo: userId).get();

      return snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch created clubs: $e');
    }
  }

  // Approve club (admin only)
  Future<void> approveClub(String clubId, String adminId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'status': 'approved',
        'approvedAt': Timestamp.now(),
        'approvedBy': adminId,
      });
    } catch (e) {
      throw Exception('Failed to approve club: $e');
    }
  }

  // Reject club (admin only)
  Future<void> rejectClub(String clubId, String reason) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to reject club: $e');
    }
  }

  // Join club
  Future<void> joinClub(String clubId, String userId, String userName) async {
    try {
      final club = await getClubById(clubId);
      if (club == null) throw Exception('Club not found');

      if (!club.memberIds.contains(userId)) {
        // Update main club document
        await _firestore.collection('clubs').doc(clubId).update({
          'memberIds': FieldValue.arrayUnion([userId]),
          'memberCount': FieldValue.increment(1),
        });

        // Get user data for member document
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        
        // Create member document in subcollection
        await _firestore.collection('clubs').doc(clubId).collection('members').doc(userId).set({
          'clubId': clubId,
          'name': userData?['name'] ?? userName,
          'imageUrl': userData?['profileImageUrl'],
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }
    } catch (e) {
      throw Exception('Failed to join club: $e');
    }
  }

  // Leave club
  Future<void> leaveClub(String clubId, String userId) async {
    try {
      final club = await getClubById(clubId);
      if (club == null) throw Exception('Club not found');

      if (club.memberIds.contains(userId)) {
        await _firestore.collection('clubs').doc(clubId).update({
          'memberIds': FieldValue.arrayRemove([userId]),
          'memberCount': FieldValue.increment(-1),
        });
        
        // Remove member document from subcollection
        await _firestore.collection('clubs').doc(clubId).collection('members').doc(userId).delete();
      }

      // Remove from leaders if applicable
      if (club.leaderIds.contains(userId)) {
        await _firestore.collection('clubs').doc(clubId).update({
          'leaderIds': FieldValue.arrayRemove([userId]),
        });
      }
    } catch (e) {
      throw Exception('Failed to leave club: $e');
    }
  }

  // Add leader to club
  Future<void> addLeader(String clubId, String userId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'leaderIds': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to add leader: $e');
    }
  }

  // Remove leader from club
  Future<void> removeLeader(String clubId, String userId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'leaderIds': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove leader: $e');
    }
  }

  // Update club details (leaders only)
  Future<void> updateClub(String clubId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update(updates);
    } catch (e) {
      throw Exception('Failed to update club: $e');
    }
  }

  // Post activity to club
  Future<String> postActivity({
    required String clubId,
    required String title,
    required String content,
    required String type, // 'post', 'event', 'announcement'
    String? imageUrl,
    DateTime? eventDate,
    String? location,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? 'Anonymous';
      final userImage = _auth.currentUser?.photoURL;

      if (userId == null) throw Exception('User not authenticated');

      final activity = ClubActivity(
        id: '',
        clubId: clubId,
        authorId: userId,
        authorName: userName,
        authorImageUrl: userImage,
        title: title,
        content: content,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByUserIds: [],
        commentCount: 0,
        type: type,
        eventDate: eventDate,
        location: location,
      );

      final docRef =
          await _firestore.collection('clubs').doc(clubId).collection('activities').add(activity.toFirestore());

      // Increment activity count
      await _firestore.collection('clubs').doc(clubId).update({
        'activityCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to post activity: $e');
    }
  }

  // Create event activity with full location support
  Future<String> createActivity({
    required String clubId,
    required String content,
    required String authorName,
    required String type,
    String? eventTitle,
    DateTime? eventDate,
    String? eventLocation,
    double? eventLatitude,
    double? eventLongitude,
    String? imageUrl,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? authorName;
      final userImage = _auth.currentUser?.photoURL;

      if (userId == null) throw Exception('User not authenticated');

      final activity = ClubActivity(
        id: '',
        clubId: clubId,
        authorId: userId,
        authorName: userName,
        authorImageUrl: userImage,
        title: eventTitle ?? '',
        content: content,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByUserIds: [],
        commentCount: 0,
        type: type,
        eventDate: eventDate,
        location: eventLocation,
        eventLatitude: eventLatitude,
        eventLongitude: eventLongitude,
      );

      final docRef = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('activities')
          .add(activity.toFirestore());

      // Increment activity count
      await _firestore.collection('clubs').doc(clubId).update({
        'activityCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create activity: $e');
    }
  }

  // Get club activities
  Future<List<ClubActivity>> getClubActivities(String clubId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => ClubActivity.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch activities: $e');
    }
  }

  // Like activity
  Future<void> likeActivity(String clubId, String activityId, String userId) async {
    try {
      final activity = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('activities')
          .doc(activityId)
          .get();

      if (!activity.exists) throw Exception('Activity not found');

      final likedByUsers = List<String>.from(activity['likedByUserIds'] ?? []);
      if (!likedByUsers.contains(userId)) {
        await _firestore
            .collection('clubs')
            .doc(clubId)
            .collection('activities')
            .doc(activityId)
            .update({
          'likedByUserIds': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      throw Exception('Failed to like activity: $e');
    }
  }

  // Unlike activity
  Future<void> unlikeActivity(String clubId, String activityId, String userId) async {
    try {
      await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('activities')
          .doc(activityId)
          .update({
        'likedByUserIds': FieldValue.arrayRemove([userId]),
        'likeCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to unlike activity: $e');
    }
  }

  // Get club members
  Future<List<ClubMember>> getClubMembers(String clubId) async {
    try {
      final snapshot = await _firestore.collection('clubs').doc(clubId).collection('members').get();

      return snapshot.docs.map((doc) => ClubMember.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch club members: $e');
    }
  }

  // Archive club (admin/creator only)
  Future<void> archiveClub(String clubId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'status': 'archived',
      });
    } catch (e) {
      throw Exception('Failed to archive club: $e');
    }
  }

  // Delete club (admin only - hard delete)
  Future<void> deleteClub(String clubId) async {
    try {
      // Delete all activities first
      final activities =
          await _firestore.collection('clubs').doc(clubId).collection('activities').get();
      for (var activity in activities.docs) {
        await activity.reference.delete();
      }

      // Delete all members
      final members =
          await _firestore.collection('clubs').doc(clubId).collection('members').get();
      for (var member in members.docs) {
        await member.reference.delete();
      }

      // Delete club
      await _firestore.collection('clubs').doc(clubId).delete();
    } catch (e) {
      throw Exception('Failed to delete club: $e');
    }
  }

  // Stream approved clubs
  Stream<List<Club>> streamApprovedClubs({ClubCategory? category}) {
    Query query = _firestore.collection('clubs').where('status', isEqualTo: 'approved');

    if (category != null) {
      query = query.where('category', isEqualTo: category.toString().split('.').last);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  // Stream pending clubs (admin)
  Stream<List<Club>> streamPendingClubs() {
    return _firestore.collection('clubs').where('status', isEqualTo: 'pending').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  // Stream club details
  Stream<Club?> streamClubDetails(String clubId) {
    return _firestore.collection('clubs').doc(clubId).snapshots().map((doc) =>
        doc.exists ? Club.fromFirestore(doc) : null);
  }

  // Stream club activities
  Stream<List<ClubActivity>> streamClubActivities(String clubId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ClubActivity.fromFirestore(doc)).toList());
  }

  // Add message to club chat
  Future<String> addMessage(String clubId, ClubMessage message) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final docRef = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('messages')
          .add(message.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages for a club
  Future<List<ClubMessage>> getMessages(String clubId, {int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => ClubMessage.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  // Stream messages for real-time updates
  Stream<List<ClubMessage>> streamMessages(String clubId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ClubMessage.fromFirestore(doc)).toList());
  }

  // Migrate existing club members from memberIds array to members subcollection
  // Call this once to populate members subcollection for existing clubs
  Future<void> migrateClubMembers(String clubId) async {
    try {
      final club = await getClubById(clubId);
      if (club == null) throw Exception('Club not found');

      // Check if migration already done
      final existingMembers = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .limit(1)
          .get();
      
      if (existingMembers.docs.isNotEmpty) {
        print('Club $clubId already has members subcollection');
        return;
      }

      // Fetch user data for all members and create member documents
      for (String userId in club.memberIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data();
          
          final isLeader = club.leaderIds.contains(userId);
          final isCreator = club.creatorId == userId;
          
          await _firestore.collection('clubs').doc(clubId).collection('members').doc(userId).set({
            'clubId': clubId,
            'name': userData?['name'] ?? (isCreator ? club.creatorName : 'Unknown'),
            'imageUrl': userData?['profileImageUrl'] ?? (isCreator ? club.creatorImageUrl : null),
            'role': isLeader ? 'leader' : 'member',
            'joinedAt': isCreator ? Timestamp.fromDate(club.createdAt) : FieldValue.serverTimestamp(),
            'isActive': true,
          });
        } catch (e) {
          print('Failed to migrate member $userId: $e');
        }
      }
      
      print('Successfully migrated ${club.memberIds.length} members for club $clubId');
    } catch (e) {
      throw Exception('Failed to migrate club members: $e');
    }
  }

  // Migrate all clubs - run this once
  Future<void> migrateAllClubMembers() async {
    try {
      final clubs = await _firestore.collection('clubs').get();
      
      for (var clubDoc in clubs.docs) {
        await migrateClubMembers(clubDoc.id);
      }
      
      print('Successfully migrated all clubs');
    } catch (e) {
      throw Exception('Failed to migrate all clubs: $e');
    }
  }
}
