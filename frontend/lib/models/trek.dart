import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a geographical point with coordinates and optional metadata
class GeoPoint {
  final double latitude;
  final double longitude;
  final double? elevation;
  final DateTime? timestamp;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.timestamp,
  });

  factory GeoPoint.fromMap(Map<String, dynamic> map) {
    return GeoPoint(
      latitude: (map['latitude'] ?? map['lat'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? map['lng'] ?? 0.0).toDouble(),
      elevation: map['elevation']?.toDouble(),
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.parse(map['timestamp'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (elevation != null) 'elevation': elevation,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    };
  }

  @override
  String toString() => 'GeoPoint($latitude, $longitude, elev: $elevation)';
}

/// Represents a geospatial location with geopoint and geohash for efficient queries
/// This enables geohash-based queries in Firestore for nearby location searches
class TrekLocation {
  final GeoPoint geopoint;
  final String geohash;

  const TrekLocation({
    required this.geopoint,
    required this.geohash,
  });

  factory TrekLocation.fromMap(Map<String, dynamic> map) {
    // Handle both nested geopoint format and flat format
    GeoPoint geopoint;
    if (map['geopoint'] != null) {
      geopoint = GeoPoint.fromMap(map['geopoint'] as Map<String, dynamic>);
    } else if (map['latitude'] != null && map['longitude'] != null) {
      geopoint = GeoPoint(
        latitude: (map['latitude'] ?? 0.0).toDouble(),
        longitude: (map['longitude'] ?? 0.0).toDouble(),
      );
    } else {
      geopoint = const GeoPoint(latitude: 0, longitude: 0);
    }
    
    return TrekLocation(
      geopoint: geopoint,
      geohash: map['geohash']?.toString() ?? '',
    );
  }

  /// Create TrekLocation from GeoPoint with automatic geohash generation
  factory TrekLocation.fromGeoPoint(GeoPoint point, {int precision = 9}) {
    final geohash = _encodeGeohash(point.latitude, point.longitude, precision);
    return TrekLocation(geopoint: point, geohash: geohash);
  }

  Map<String, dynamic> toMap() {
    return {
      'geopoint': geopoint.toMap(),
      'geohash': geohash,
    };
  }

  /// Encode latitude/longitude to geohash
  static String _encodeGeohash(double latitude, double longitude, int precision) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    
    double minLat = -90.0;
    double maxLat = 90.0;
    double minLon = -180.0;
    double maxLon = 180.0;
    
    StringBuffer hash = StringBuffer();
    bool isLon = true;
    int bits = 0;
    int charIndex = 0;
    
    while (hash.length < precision) {
      if (isLon) {
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          charIndex = (charIndex << 1) | 1;
          minLon = mid;
        } else {
          charIndex = charIndex << 1;
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          charIndex = (charIndex << 1) | 1;
          minLat = mid;
        } else {
          charIndex = charIndex << 1;
          maxLat = mid;
        }
      }
      
      isLon = !isLon;
      bits++;
      
      if (bits == 5) {
        hash.write(base32[charIndex]);
        bits = 0;
        charIndex = 0;
      }
    }
    
    return hash.toString();
  }

  @override
  String toString() => 'TrekLocation(${geopoint.latitude}, ${geopoint.longitude}, geohash: $geohash)';
}

/// Elevation point for elevation profile chart
class ElevationPoint {
  final double distance; // Distance from start in meters
  final double elevation; // Elevation in meters

  const ElevationPoint({
    required this.distance,
    required this.elevation,
  });

  factory ElevationPoint.fromMap(Map<String, dynamic> map) {
    return ElevationPoint(
      distance: (map['distance'] ?? 0.0).toDouble(),
      elevation: (map['elevation'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'elevation': elevation,
    };
  }
}

/// Trek difficulty levels
enum TrekDifficulty {
  easy,
  moderate,
  difficult,
  expert;

  String get displayName {
    switch (this) {
      case TrekDifficulty.easy:
        return 'Easy';
      case TrekDifficulty.moderate:
        return 'Moderate';
      case TrekDifficulty.difficult:
        return 'Difficult';
      case TrekDifficulty.expert:
        return 'Expert';
    }
  }

  static TrekDifficulty fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'easy':
        return TrekDifficulty.easy;
      case 'moderate':
        return TrekDifficulty.moderate;
      case 'difficult':
        return TrekDifficulty.difficult;
      case 'expert':
        return TrekDifficulty.expert;
      default:
        return TrekDifficulty.moderate;
    }
  }
}

/// Trek category/type
enum TrekCategory {
  walkingPath,
  trekkingPoint,
  natureWalk,
  cyclePath,
  pointOfInterest,
  fitnessCenter,
  // Fitness sub-categories
  sportsClub,
  gym,
  swimmingPool,
  yogaCenter,
  artsCenter;

  String get displayName {
    switch (this) {
      case TrekCategory.walkingPath:
        return 'Walking paths';
      case TrekCategory.trekkingPoint:
        return 'Trekking points';
      case TrekCategory.natureWalk:
        return 'Nature walks';
      case TrekCategory.cyclePath:
        return 'Cycle paths';
      case TrekCategory.pointOfInterest:
        return 'Points of Interest';
      case TrekCategory.fitnessCenter:
        return 'Fitness Center';
      case TrekCategory.sportsClub:
        return 'Sports Clubs';
      case TrekCategory.gym:
        return 'Gym';
      case TrekCategory.swimmingPool:
        return 'Swimming Pools';
      case TrekCategory.yogaCenter:
        return 'Yoga Center';
      case TrekCategory.artsCenter:
        return 'Arts Center';
    }
  }

  String get iconName {
    switch (this) {
      case TrekCategory.walkingPath:
        return 'directions_walk';
      case TrekCategory.trekkingPoint:
        return 'terrain';
      case TrekCategory.natureWalk:
        return 'park';
      case TrekCategory.cyclePath:
        return 'directions_bike';
      case TrekCategory.pointOfInterest:
        return 'place';
      case TrekCategory.fitnessCenter:
        return 'fitness_center';
      case TrekCategory.sportsClub:
        return 'sports_soccer';
      case TrekCategory.gym:
        return 'fitness_center';
      case TrekCategory.swimmingPool:
        return 'pool';
      case TrekCategory.yogaCenter:
        return 'self_improvement';
      case TrekCategory.artsCenter:
        return 'palette';
    }
  }

  /// Check if this is a fitness sub-category
  bool get isFitnessSubCategory {
    return this == TrekCategory.sportsClub ||
           this == TrekCategory.gym ||
           this == TrekCategory.swimmingPool ||
           this == TrekCategory.yogaCenter ||
           this == TrekCategory.artsCenter ||
           this == TrekCategory.fitnessCenter;
  }

  static TrekCategory fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'walking_path':
      case 'walkingpath':
        return TrekCategory.walkingPath;
      case 'trekking_point':
      case 'trekkingpoint':
        return TrekCategory.trekkingPoint;
      case 'nature_walk':
      case 'naturewalk':
        return TrekCategory.natureWalk;
      case 'cycle_path':
      case 'cyclepath':
        return TrekCategory.cyclePath;
      case 'point_of_interest':
      case 'poi':
        return TrekCategory.pointOfInterest;
      case 'fitness_center':
      case 'fitnesscenter':
        return TrekCategory.fitnessCenter;
      case 'sports_club':
      case 'sportsclub':
        return TrekCategory.sportsClub;
      case 'gym':
        return TrekCategory.gym;
      case 'swimming_pool':
      case 'swimmingpool':
        return TrekCategory.swimmingPool;
      case 'yoga_center':
      case 'yogacenter':
        return TrekCategory.yogaCenter;
      case 'arts_center':
      case 'artscenter':
        return TrekCategory.artsCenter;
      default:
        return TrekCategory.walkingPath;
    }
  }
}

/// Main Trek model representing a trek/path in Firestore
class Trek {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final double distance; // in meters
  final int estimatedTimeMinutes;
  final TrekDifficulty difficulty;
  final TrekCategory category;
  final List<GeoPoint> routePoints;
  final List<ElevationPoint> elevationProfile;
  final double elevationGain; // in meters
  final double elevationLoss; // in meters
  final double minElevation;
  final double maxElevation;
  final int usersToday;
  final double rating;
  final int reviewCount;
  final String? gpxData;
  final GeoPoint? startPoint;
  final GeoPoint? endPoint;
  final TrekLocation? location; // Geohash-indexed location for nearby queries
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final bool isPublic;
  final List<String> tags;

  const Trek({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.distance,
    required this.estimatedTimeMinutes,
    required this.difficulty,
    required this.category,
    this.routePoints = const [],
    this.elevationProfile = const [],
    this.elevationGain = 0,
    this.elevationLoss = 0,
    this.minElevation = 0,
    this.maxElevation = 0,
    this.usersToday = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.gpxData,
    this.startPoint,
    this.endPoint,
    this.location,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.isPublic = true,
    this.tags = const [],
  });

  /// Creates a Trek from Firestore document
  factory Trek.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Trek.fromMap(data, doc.id);
  }

  factory Trek.fromMap(Map<String, dynamic> map, [String? docId]) {
    final routePointsData = map['routePoints'] as List<dynamic>? ?? [];
    final elevationProfileData = map['elevationProfile'] as List<dynamic>? ?? [];
    final tagsData = map['tags'] as List<dynamic>? ?? [];

    // Parse location field for geohash queries, fallback to startPoint
    TrekLocation? location;
    if (map['location'] != null) {
      location = TrekLocation.fromMap(map['location'] as Map<String, dynamic>);
    } else if (map['startPoint'] != null) {
      // Fallback: generate location from startPoint for backward compatibility
      final startPt = GeoPoint.fromMap(map['startPoint'] as Map<String, dynamic>);
      location = TrekLocation.fromGeoPoint(startPt);
    }

    return Trek(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? 'Untitled Trek',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? map['imageURL'],
      distance: (map['distance'] ?? 0).toDouble(),
      estimatedTimeMinutes: map['estimatedTimeMinutes'] ?? map['estimatedTime'] ?? 60,
      difficulty: TrekDifficulty.fromString(map['difficulty']),
      category: TrekCategory.fromString(map['category']),
      routePoints: routePointsData
          .map((p) => GeoPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      elevationProfile: elevationProfileData
          .map((p) => ElevationPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      elevationGain: (map['elevationGain'] ?? 0).toDouble(),
      elevationLoss: (map['elevationLoss'] ?? 0).toDouble(),
      minElevation: (map['minElevation'] ?? 0).toDouble(),
      maxElevation: (map['maxElevation'] ?? 0).toDouble(),
      usersToday: map['usersToday'] ?? 0,
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      gpxData: map['gpxData'] ?? map['routeGPX'],
      startPoint: map['startPoint'] != null
          ? GeoPoint.fromMap(map['startPoint'] as Map<String, dynamic>)
          : null,
      endPoint: map['endPoint'] != null
          ? GeoPoint.fromMap(map['endPoint'] as Map<String, dynamic>)
          : null,
      location: location,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'].toString()))
          : DateTime.now(),
      createdBy: map['createdBy'],
      isPublic: map['isPublic'] ?? true,
      tags: tagsData.map((t) => t.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'distance': distance,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'difficulty': difficulty.name,
      'category': category.name,
      'routePoints': routePoints.map((p) => p.toMap()).toList(),
      'elevationProfile': elevationProfile.map((p) => p.toMap()).toList(),
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
      'minElevation': minElevation,
      'maxElevation': maxElevation,
      'usersToday': usersToday,
      'rating': rating,
      'reviewCount': reviewCount,
      'gpxData': gpxData,
      'startPoint': startPoint?.toMap(),
      'endPoint': endPoint?.toMap(),
      'location': location?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'isPublic': isPublic,
      'tags': tags,
    };
  }

  /// Get formatted distance string
  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.toInt()} m';
  }

  /// Get formatted time string
  String get formattedTime {
    if (estimatedTimeMinutes >= 60) {
      final hours = estimatedTimeMinutes ~/ 60;
      final mins = estimatedTimeMinutes % 60;
      if (mins == 0) {
        return '$hours hr';
      }
      return '$hours hr $mins min';
    }
    return '$estimatedTimeMinutes min';
  }

  /// Get formatted elevation gain
  String get formattedElevationGain {
    return '${elevationGain.toInt()} m';
  }

  Trek copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    double? distance,
    int? estimatedTimeMinutes,
    TrekDifficulty? difficulty,
    TrekCategory? category,
    List<GeoPoint>? routePoints,
    List<ElevationPoint>? elevationProfile,
    double? elevationGain,
    double? elevationLoss,
    double? minElevation,
    double? maxElevation,
    int? usersToday,
    double? rating,
    int? reviewCount,
    String? gpxData,
    GeoPoint? startPoint,
    GeoPoint? endPoint,
    TrekLocation? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    bool? isPublic,
    List<String>? tags,
  }) {
    return Trek(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      distance: distance ?? this.distance,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      routePoints: routePoints ?? this.routePoints,
      elevationProfile: elevationProfile ?? this.elevationProfile,
      elevationGain: elevationGain ?? this.elevationGain,
      elevationLoss: elevationLoss ?? this.elevationLoss,
      minElevation: minElevation ?? this.minElevation,
      maxElevation: maxElevation ?? this.maxElevation,
      usersToday: usersToday ?? this.usersToday,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      gpxData: gpxData ?? this.gpxData,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() => 'Trek($id, $title, $formattedDistance)';
}

/// Trek review model
class TrekReview {
  final String id;
  final String trekId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final double rating;
  final String? comment;
  final List<String> photoUrls;
  final DateTime createdAt;

  const TrekReview({
    required this.id,
    required this.trekId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    this.comment,
    this.photoUrls = const [],
    required this.createdAt,
  });

  factory TrekReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrekReview.fromMap(data, doc.id);
  }

  factory TrekReview.fromMap(Map<String, dynamic> map, [String? docId]) {
    final photoUrlsData = map['photoUrls'] as List<dynamic>? ?? [];

    return TrekReview(
      id: docId ?? map['id'] ?? '',
      trekId: map['trekId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      userAvatarUrl: map['userAvatarUrl'],
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'],
      photoUrls: photoUrlsData.map((u) => u.toString()).toList(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trekId': trekId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'rating': rating,
      'comment': comment,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// User recorded track model
class RecordedTrack {
  final String id;
  final String? title;
  final String? notes;
  final DateTime startTime;
  final DateTime endTime;
  final double distance; // in meters
  final List<GeoPoint> points;
  final String? mapSnapshotUrl;
  final double caloriesBurned;
  final double avgSpeed; // m/s
  final double maxSpeed;
  final double elevationGain;
  final double elevationLoss;
  final String userId;

  const RecordedTrack({
    required this.id,
    this.title,
    this.notes,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.points,
    this.mapSnapshotUrl,
    this.caloriesBurned = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.elevationGain = 0,
    this.elevationLoss = 0,
    required this.userId,
  });

  factory RecordedTrack.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RecordedTrack.fromMap(data, doc.id);
  }

  factory RecordedTrack.fromMap(Map<String, dynamic> map, [String? docId]) {
    final pointsData = map['points'] as List<dynamic>? ?? [];

    return RecordedTrack(
      id: docId ?? map['id'] ?? '',
      title: map['title'],
      notes: map['notes'],
      startTime: map['startTime'] != null
          ? (map['startTime'] is Timestamp
              ? (map['startTime'] as Timestamp).toDate()
              : DateTime.parse(map['startTime'].toString()))
          : DateTime.now(),
      endTime: map['endTime'] != null
          ? (map['endTime'] is Timestamp
              ? (map['endTime'] as Timestamp).toDate()
              : DateTime.parse(map['endTime'].toString()))
          : DateTime.now(),
      distance: (map['distance'] ?? 0).toDouble(),
      points: pointsData
          .map((p) => GeoPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      mapSnapshotUrl: map['mapSnapshotUrl'] ?? map['mapSnapshotURL'],
      caloriesBurned: (map['caloriesBurned'] ?? 0).toDouble(),
      avgSpeed: (map['avgSpeed'] ?? 0).toDouble(),
      maxSpeed: (map['maxSpeed'] ?? 0).toDouble(),
      elevationGain: (map['elevationGain'] ?? 0).toDouble(),
      elevationLoss: (map['elevationLoss'] ?? 0).toDouble(),
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'notes': notes,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'distance': distance,
      'points': points.map((p) => p.toMap()).toList(),
      'mapSnapshotUrl': mapSnapshotUrl,
      'caloriesBurned': caloriesBurned,
      'avgSpeed': avgSpeed,
      'maxSpeed': maxSpeed,
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
      'userId': userId,
    };
  }

  /// Get duration in seconds
  int get durationSeconds => endTime.difference(startTime).inSeconds;

  /// Get formatted duration
  String get formattedDuration {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Get formatted distance
  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
    return '${distance.toInt()} m';
  }

  /// Get formatted pace (min/km)
  String get formattedPace {
    if (distance <= 0) return '--:--';
    final paceSecondsPerKm = durationSeconds / (distance / 1000);
    final paceMinutes = (paceSecondsPerKm / 60).floor();
    final paceSeconds = (paceSecondsPerKm % 60).floor();
    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}';
  }
}

/// Favorite trek reference
class FavoriteTrek {
  final String id;
  final String trekId;
  final String userId;
  final DateTime addedAt;

  const FavoriteTrek({
    required this.id,
    required this.trekId,
    required this.userId,
    required this.addedAt,
  });

  factory FavoriteTrek.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FavoriteTrek(
      id: doc.id,
      trekId: data['trekId'] ?? '',
      userId: data['userId'] ?? '',
      addedAt: data['addedAt'] != null
          ? (data['addedAt'] is Timestamp
              ? (data['addedAt'] as Timestamp).toDate()
              : DateTime.parse(data['addedAt'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trekId': trekId,
      'userId': userId,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
