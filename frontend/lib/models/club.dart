import 'package:cloud_firestore/cloud_firestore.dart';

enum ClubCategory {
  environment,
  wildlife,
  conservation,
  sustainability,
  community,
  education,
  health,
  other
}

enum ClubStatus {
  pending,
  approved,
  rejected,
  archived
}

class Club {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final ClubCategory category;
  final ClubStatus status;
  final String creatorId;
  final String creatorName;
  final String? creatorImageUrl;
  final List<String> leaderIds;
  final List<String> memberIds;
  final String location;
  final double? latitude;
  final double? longitude;
  final int memberCount;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime? rejectedAt;
  final int activityCount;
  final List<String> tags;
  final String? website;
  final String? contactEmail;
  final String? phoneNumber;

  Club({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.category,
    required this.status,
    required this.creatorId,
    required this.creatorName,
    this.creatorImageUrl,
    required this.leaderIds,
    required this.memberIds,
    required this.location,
    this.latitude,
    this.longitude,
    required this.memberCount,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.rejectedAt,
    required this.activityCount,
    required this.tags,
    this.website,
    this.contactEmail,
    this.phoneNumber,
  });

  factory Club.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      category: ClubCategory.values.firstWhere(
        (e) => e.toString() == 'ClubCategory.${data['category']}',
        orElse: () => ClubCategory.other,
      ),
      status: ClubStatus.values.firstWhere(
        (e) => e.toString() == 'ClubStatus.${data['status']}',
        orElse: () => ClubStatus.pending,
      ),
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      creatorImageUrl: data['creatorImageUrl'],
      leaderIds: List<String>.from(data['leaderIds'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      location: data['location'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      memberCount: data['memberCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      activityCount: data['activityCount'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      website: data['website'],
      contactEmail: data['contactEmail'],
      phoneNumber: data['phoneNumber'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'category': category.toString().split('.').last,
      'status': status.toString().split('.').last,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorImageUrl': creatorImageUrl,
      'leaderIds': leaderIds,
      'memberIds': memberIds,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'memberCount': memberCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'activityCount': activityCount,
      'tags': tags,
      'website': website,
      'contactEmail': contactEmail,
      'phoneNumber': phoneNumber,
    };
  }

  Club copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    ClubCategory? category,
    ClubStatus? status,
    String? creatorId,
    String? creatorName,
    String? creatorImageUrl,
    List<String>? leaderIds,
    List<String>? memberIds,
    String? location,
    double? latitude,
    double? longitude,
    int? memberCount,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
    DateTime? rejectedAt,
    int? activityCount,
    List<String>? tags,
    String? website,
    String? contactEmail,
    String? phoneNumber,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      status: status ?? this.status,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorImageUrl: creatorImageUrl ?? this.creatorImageUrl,
      leaderIds: leaderIds ?? this.leaderIds,
      memberIds: memberIds ?? this.memberIds,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      activityCount: activityCount ?? this.activityCount,
      tags: tags ?? this.tags,
      website: website ?? this.website,
      contactEmail: contactEmail ?? this.contactEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  // Helper getters
  bool get isApproved => status == ClubStatus.approved;
  bool get isPending => status == ClubStatus.pending;
  bool get isRejected => status == ClubStatus.rejected;
  bool get isActive => isApproved && status != ClubStatus.archived;

  String get categoryName {
    switch (category) {
      case ClubCategory.environment:
        return 'Environment';
      case ClubCategory.wildlife:
        return 'Wildlife';
      case ClubCategory.conservation:
        return 'Conservation';
      case ClubCategory.sustainability:
        return 'Sustainability';
      case ClubCategory.community:
        return 'Community';
      case ClubCategory.education:
        return 'Education';
      case ClubCategory.health:
        return 'Health';
      case ClubCategory.other:
        return 'Other';
    }
  }

  String get statusName {
    switch (status) {
      case ClubStatus.pending:
        return 'Pending Approval';
      case ClubStatus.approved:
        return 'Approved';
      case ClubStatus.rejected:
        return 'Rejected';
      case ClubStatus.archived:
        return 'Archived';
    }
  }
}

class ClubActivity {
  final String id;
  final String clubId;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String title;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likedByUserIds;
  final int commentCount;
  final String type; // 'post', 'event', 'announcement'
  final DateTime? eventDate;
  final String? location;
  final double? eventLatitude;
  final double? eventLongitude;

  ClubActivity({
    required this.id,
    required this.clubId,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.likeCount,
    required this.likedByUserIds,
    required this.commentCount,
    required this.type,
    this.eventDate,
    this.location,
    this.eventLatitude,
    this.eventLongitude,
  });

  factory ClubActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubActivity(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorImageUrl: data['authorImageUrl'],
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      type: data['type'] ?? 'post',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      location: data['location'],
      eventLatitude: data['eventLatitude'],
      eventLongitude: data['eventLongitude'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'authorId': authorId,
      'authorName': authorName,
      'authorImageUrl': authorImageUrl,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likedByUserIds': likedByUserIds,
      'commentCount': commentCount,
      'type': type,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'location': location,
      'eventLatitude': eventLatitude,
      'eventLongitude': eventLongitude,
    };
  }
}

class ClubMember {
  final String userId;
  final String clubId;
  final String name;
  final String? imageUrl;
  final String role; // 'leader' or 'member'
  final DateTime joinedAt;
  final bool isActive;

  ClubMember({
    required this.userId,
    required this.clubId,
    required this.name,
    this.imageUrl,
    required this.role,
    required this.joinedAt,
    required this.isActive,
  });

  factory ClubMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubMember(
      userId: doc.id,
      clubId: data['clubId'] ?? '',
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
      role: data['role'] ?? 'member',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'name': name,
      'imageUrl': imageUrl,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
    };
  }
}
/// Club message model for chat functionality
class ClubMessage {
  final String id;
  final String clubId;
  final String userId;
  final String userName;
  final String? userImage;
  final String content;
  final DateTime timestamp;

  ClubMessage({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.content,
    required this.timestamp,
  });

  factory ClubMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubMessage(
      id: doc.id,
      clubId: data['clubId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userImage: data['userImage'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}