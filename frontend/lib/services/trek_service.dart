import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/trek.dart';
import '../utils/geo_utils.dart';

/// Custom exception for TrekService errors
class TrekServiceException implements Exception {
  final String message;
  const TrekServiceException(this.message);
  
  @override
  String toString() => 'TrekServiceException: $message';
}

/// Service for managing treks in Firestore
/// Implements production-grade patterns with proper error handling,
/// batched writes, caching, and geohash-based queries
class TrekService {
  static final TrekService _instance = TrekService._internal();
  factory TrekService() => _instance;
  TrekService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for frequently accessed data
  final Map<String, Trek> _trekCache = {};
  final Duration _cacheExpiry = const Duration(minutes: 5);
  DateTime? _lastCacheUpdate;
  
  // Timeout for Firestore operations
  static const Duration _operationTimeout = Duration(seconds: 30);

  // Collection references
  CollectionReference<Map<String, dynamic>> get _treksCollection =>
      _firestore.collection('treks');

  CollectionReference<Map<String, dynamic>> _reviewsCollection(String trekId) =>
      _treksCollection.doc(trekId).collection('reviews');

  CollectionReference<Map<String, dynamic>> get _userTracksCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('tracks');
  }

  CollectionReference<Map<String, dynamic>> get _userFavoritesCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    return _firestore.collection('users').doc(uid).collection('favorites');
  }
  
  /// Clear local cache
  void clearCache() {
    _trekCache.clear();
    _lastCacheUpdate = null;
  }
  
  /// Check if cache is valid
  bool get _isCacheValid {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  // ============ TREKS ============

  /// Fetch all treks with optional filtering and pagination
  /// Uses client-side caching and error handling
  Future<List<Trek>> getTreks({
    TrekCategory? category,
    TrekDifficulty? difficulty,
    String? searchQuery,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // Simple query without composite index requirement
      Query<Map<String, dynamic>> query = _treksCollection.limit(limit * 2);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get().timeout(_operationTimeout);
      
      // Client-side filtering for flexibility without index requirements
      List<Trek> treks = snapshot.docs
          .map((doc) {
            try {
              return Trek.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing trek ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Trek>()
          .where((trek) => trek.isPublic)
          .toList();

      // Filter by category
      if (category != null) {
        treks = treks.where((trek) => trek.category == category).toList();
      }

      // Filter by difficulty
      if (difficulty != null) {
        treks = treks.where((trek) => trek.difficulty == difficulty).toList();
      }

      // Client-side search filtering if query provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        treks = treks.where((trek) {
          return trek.title.toLowerCase().contains(lowerQuery) ||
              trek.description.toLowerCase().contains(lowerQuery) ||
              trek.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList();
      }

      // Sort by createdAt descending
      treks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Update cache
      for (final trek in treks) {
        _trekCache[trek.id] = trek;
      }
      _lastCacheUpdate = DateTime.now();

      return treks.take(limit).toList();
    } on TimeoutException {
      throw TrekServiceException('Request timed out. Please check your connection.');
    } on FirebaseException catch (e) {
      throw TrekServiceException('Database error: ${e.message}');
    } catch (e) {
      throw TrekServiceException('Failed to fetch treks: $e');
    }
  }

  /// Get a single trek by ID with caching
  Future<Trek?> getTrekById(String trekId) async {
    if (trekId.isEmpty) return null;
    
    try {
      // Check cache first
      if (_isCacheValid && _trekCache.containsKey(trekId)) {
        return _trekCache[trekId];
      }
      
      final doc = await _treksCollection.doc(trekId).get().timeout(_operationTimeout);
      if (!doc.exists) return null;
      
      final trek = Trek.fromFirestore(doc);
      _trekCache[trekId] = trek;
      return trek;
    } on TimeoutException {
      // Return cached version if available
      if (_trekCache.containsKey(trekId)) {
        return _trekCache[trekId];
      }
      throw TrekServiceException('Request timed out');
    } catch (e) {
      throw TrekServiceException('Failed to fetch trek: $e');
    }
  }

  /// Stream a single trek for real-time updates
  Stream<Trek?> streamTrek(String trekId) {
    if (trekId.isEmpty) return Stream.value(null);
    
    return _treksCollection.doc(trekId).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        final trek = Trek.fromFirestore(doc);
        _trekCache[trekId] = trek;
        return trek;
      } catch (e) {
        debugPrint('Error parsing trek $trekId: $e');
        return null;
      }
    }).handleError((e) {
      debugPrint('Stream error for trek $trekId: $e');
      return null;
    });
  }

  /// Stream all treks with filtering
  Stream<List<Trek>> streamTreks({
    TrekCategory? category,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _treksCollection.limit(limit * 2);

    return query.snapshots().map((snapshot) {
      List<Trek> treks = snapshot.docs
          .map((doc) {
            try {
              return Trek.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing trek ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Trek>()
          .where((trek) => trek.isPublic)
          .toList();
      
      if (category != null) {
        treks = treks.where((trek) => trek.category == category).toList();
      }
      
      treks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return treks.take(limit).toList();
    }).handleError((e) {
      debugPrint('Stream error: $e');
      return <Trek>[];
    });
  }

  /// Create a new trek with validation and automatic location generation
  Future<String> createTrek(Trek trek) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    
    // Validate required fields
    if (trek.title.trim().isEmpty) {
      throw TrekServiceException('Trek title is required');
    }
    
    try {
      // Generate location from startPoint if not provided
      TrekLocation? location = trek.location;
      if (location == null && trek.startPoint != null) {
        location = TrekLocation.fromGeoPoint(trek.startPoint!);
      }
      
      final trekData = trek.copyWith(
        createdBy: uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        location: location,
      ).toMap();
      
      final docRef = await _treksCollection.add(trekData).timeout(_operationTimeout);
      
      // Update cache
      final newTrek = trek.copyWith(id: docRef.id);
      _trekCache[docRef.id] = newTrek;
      
      return docRef.id;
    } catch (e) {
      throw TrekServiceException('Failed to create trek: $e');
    }
  }

  /// Update a trek with merge option
  Future<void> updateTrek(Trek trek) async {
    if (trek.id.isEmpty) throw TrekServiceException('Trek ID is required');
    
    try {
      final updateData = trek.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();
      
      await _treksCollection.doc(trek.id).set(
        updateData,
        SetOptions(merge: true),
      ).timeout(_operationTimeout);
      
      // Update cache
      _trekCache[trek.id] = trek;
    } catch (e) {
      throw TrekServiceException('Failed to update trek: $e');
    }
  }

  /// Delete a trek
  Future<void> deleteTrek(String trekId) async {
    if (trekId.isEmpty) throw TrekServiceException('Trek ID is required');
    
    try {
      await _treksCollection.doc(trekId).delete().timeout(_operationTimeout);
      _trekCache.remove(trekId);
    } catch (e) {
      throw TrekServiceException('Failed to delete trek: $e');
    }
  }

  /// Increment users today count atomically
  Future<void> incrementUsersToday(String trekId) async {
    if (trekId.isEmpty) return;
    
    try {
      await _treksCollection.doc(trekId).update({
        'usersToday': FieldValue.increment(1),
      }).timeout(_operationTimeout);
    } catch (e) {
      debugPrint('Failed to increment users today: $e');
      // Non-critical error, don't throw
    }
  }

  // ============ REVIEWS ============

  /// Get reviews for a trek with error handling
  Future<List<TrekReview>> getTrekReviews(String trekId, {int limit = 20}) async {
    if (trekId.isEmpty) return [];
    
    try {
      final snapshot = await _reviewsCollection(trekId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get()
          .timeout(_operationTimeout);
      
      return snapshot.docs
          .map((doc) {
            try {
              return TrekReview.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing review ${doc.id}: $e');
              return null;
            }
          })
          .whereType<TrekReview>()
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch reviews: $e');
      return [];
    }
  }

  /// Stream reviews for a trek
  Stream<List<TrekReview>> streamTrekReviews(String trekId) {
    if (trekId.isEmpty) return Stream.value([]);
    
    return _reviewsCollection(trekId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return TrekReview.fromFirestore(doc);
                } catch (e) {
                  debugPrint('Error parsing review ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<TrekReview>()
              .toList();
        })
        .handleError((e) {
          debugPrint('Stream error for reviews: $e');
          return <TrekReview>[];
        });
  }

  /// Add a review with validation
  Future<void> addReview(TrekReview review) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    if (review.trekId.isEmpty) throw TrekServiceException('Trek ID is required');
    if (review.rating < 0 || review.rating > 5) {
      throw TrekServiceException('Rating must be between 0 and 5');
    }
    
    try {
      // Ensure userId matches current user
      final reviewData = review.toMap();
      reviewData['userId'] = uid;
      
      await _reviewsCollection(review.trekId).add(reviewData).timeout(_operationTimeout);
      
      // Update trek rating asynchronously (don't wait)
      _updateTrekRating(review.trekId);
    } catch (e) {
      throw TrekServiceException('Failed to add review: $e');
    }
  }

  /// Update trek rating based on reviews (batched write)
  Future<void> _updateTrekRating(String trekId) async {
    try {
      final reviews = await getTrekReviews(trekId, limit: 100);
      if (reviews.isEmpty) return;

      final totalRating = reviews.fold<double>(0, (total, r) => total + r.rating);
      final avgRating = totalRating / reviews.length;

      await _treksCollection.doc(trekId).set({
        'rating': avgRating,
        'reviewCount': reviews.length,
      }, SetOptions(merge: true)).timeout(_operationTimeout);
    } catch (e) {
      debugPrint('Failed to update trek rating: $e');
      // Non-critical, don't throw
    }
  }

  // ============ USER TRACKS ============

  /// Save a recorded track with validation
  Future<String> saveRecordedTrack(RecordedTrack track) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    
    try {
      // Ensure userId matches current user
      final trackData = track.toMap();
      trackData['userId'] = uid;
      
      final docRef = await _userTracksCollection.add(trackData).timeout(_operationTimeout);
      return docRef.id;
    } catch (e) {
      throw TrekServiceException('Failed to save track: $e');
    }
  }
  
  /// Save track incrementally using batched writes
  /// Use this for saving points during active tracking
  Future<void> saveTrackIncremental({
    required String trackId,
    required List<GeoPoint> newPoints,
    required double totalDistance,
    double? elevationGain,
    double? elevationLoss,
  }) async {
    if (trackId.isEmpty || newPoints.isEmpty) return;
    
    try {
      await _userTracksCollection.doc(trackId).set({
        'points': FieldValue.arrayUnion(newPoints.map((p) => p.toMap()).toList()),
        'distance': totalDistance,
        if (elevationGain != null) 'elevationGain': elevationGain,
        if (elevationLoss != null) 'elevationLoss': elevationLoss,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(_operationTimeout);
    } catch (e) {
      debugPrint('Failed to save track incrementally: $e');
      // Don't throw - we don't want to interrupt tracking
    }
  }

  /// Get user's recorded tracks with error handling
  Future<List<RecordedTrack>> getUserTracks({int limit = 20}) async {
    try {
      final snapshot = await _userTracksCollection
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get()
          .timeout(_operationTimeout);
      
      return snapshot.docs.map((doc) => RecordedTrack.fromFirestore(doc)).toList();
    } catch (e) {
      throw TrekServiceException('Failed to get user tracks: $e');
    }
  }

  /// Stream user's recorded tracks
  Stream<List<RecordedTrack>> streamUserTracks() {
    return _userTracksCollection
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => RecordedTrack.fromFirestore(doc)).toList();
        })
        .handleError((e) {
          debugPrint('Error streaming user tracks: $e');
          return <RecordedTrack>[];
        });
  }

  /// Delete a recorded track
  Future<void> deleteRecordedTrack(String trackId) async {
    if (trackId.isEmpty) throw TrekServiceException('Track ID cannot be empty');
    
    try {
      await _userTracksCollection.doc(trackId).delete().timeout(_operationTimeout);
    } catch (e) {
      throw TrekServiceException('Failed to delete track: $e');
    }
  }

  /// Update a recorded track
  Future<void> updateRecordedTrack(RecordedTrack track) async {
    if (track.id.isEmpty) throw TrekServiceException('Track ID cannot be empty');
    
    try {
      await _userTracksCollection.doc(track.id).set(
        track.toMap(),
        SetOptions(merge: true),
      ).timeout(_operationTimeout);
    } catch (e) {
      throw TrekServiceException('Failed to update track: $e');
    }
  }

  // ============ FAVORITES ============

  /// Add trek to favorites with validation
  Future<void> addToFavorites(String trekId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    if (trekId.isEmpty) throw TrekServiceException('Trek ID cannot be empty');

    try {
      await _userFavoritesCollection.doc(trekId).set({
        'trekId': trekId,
        'userId': uid,
        'addedAt': FieldValue.serverTimestamp(),
      }).timeout(_operationTimeout);
    } catch (e) {
      throw TrekServiceException('Failed to add to favorites: $e');
    }
  }

  /// Remove trek from favorites
  Future<void> removeFromFavorites(String trekId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw TrekServiceException('User not authenticated');
    if (trekId.isEmpty) throw TrekServiceException('Trek ID cannot be empty');
    
    try {
      await _userFavoritesCollection.doc(trekId).delete().timeout(_operationTimeout);
    } catch (e) {
      throw TrekServiceException('Failed to remove from favorites: $e');
    }
  }

  /// Check if trek is in favorites
  Future<bool> isFavorite(String trekId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false; // Not authenticated, can't have favorites
    if (trekId.isEmpty) return false;
    
    try {
      final doc = await _userFavoritesCollection.doc(trekId).get().timeout(_operationTimeout);
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  /// Stream favorite status
  Stream<bool> streamIsFavorite(String trekId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false); // Not authenticated
    if (trekId.isEmpty) return Stream.value(false);
    
    return _userFavoritesCollection.doc(trekId).snapshots()
        .map((doc) => doc.exists)
        .handleError((e) {
          debugPrint('Error streaming favorite status: $e');
          return false;
        });
  }

  /// Get all favorite treks
  Future<List<Trek>> getFavoriteTreks() async {
    try {
      final favorites = await _userFavoritesCollection.get().timeout(_operationTimeout);
      final trekIds = favorites.docs.map((doc) => doc.id).toList();

      if (trekIds.isEmpty) return [];

      // Firestore whereIn has a limit of 10
      final List<Trek> treks = [];
      for (var i = 0; i < trekIds.length; i += 10) {
        final batch = trekIds.skip(i).take(10).toList();
        final snapshot = await _treksCollection
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .timeout(_operationTimeout);
        treks.addAll(snapshot.docs.map((doc) => Trek.fromFirestore(doc)));
      }

      return treks;
    } catch (e) {
      throw TrekServiceException('Failed to get favorite treks: $e');
    }
  }

  /// Stream favorite trek IDs
  Stream<List<String>> streamFavoriteIds() {
    return _userFavoritesCollection.snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList())
        .handleError((e) {
          debugPrint('Error streaming favorite IDs: $e');
          return <String>[];
        });
  }

  // ============ UTILITIES ============

  /// Get treks near a location using geohash-based queries
  /// This is the production-grade implementation using geohash prefix matching
  Future<List<Trek>> getTreksNearLocation({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    TrekCategory? category,
    int limit = 20,
  }) async {
    debugPrint('getTreksNearLocation: lat=$latitude, lng=$longitude, radius=${radiusKm}km');
    
    // Get the appropriate geohash precision for the radius
    final precision = GeoUtils.getGeohashPrecisionForRadius(radiusKm);
    final centerGeohash = GeoUtils.encodeGeohash(latitude, longitude, precision: precision);
    debugPrint('Center geohash: $centerGeohash (precision: $precision)');
    
    // Get neighboring geohashes to cover the search area
    final neighbors = GeoUtils.getGeohashNeighbors(centerGeohash);
    final geohashesToQuery = [centerGeohash, ...neighbors];
    
    // Query all geohash prefixes in parallel
    final futures = geohashesToQuery.map((prefix) async {
      final upperBound = prefix.substring(0, prefix.length - 1) + 
          String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);
      
      try {
        final query = _treksCollection
            .where('location.geohash', isGreaterThanOrEqualTo: prefix)
            .where('location.geohash', isLessThan: upperBound)
            .limit(limit);
        
        final snapshot = await query.get();
        debugPrint('Geohash query "$prefix": found ${snapshot.docs.length} treks');
        return snapshot.docs.map((doc) => Trek.fromFirestore(doc)).toList();
      } catch (e) {
        debugPrint('Geohash query failed for "$prefix": $e');
        // Fallback if geohash field doesn't exist
        return <Trek>[];
      }
    });
    
    final results = await Future.wait(futures);
    
    // Merge results and remove duplicates
    final trekMap = <String, Trek>{};
    for (final trekList in results) {
      for (final trek in trekList) {
        trekMap[trek.id] = trek;
      }
    }
    
    var treks = trekMap.values.toList();
    
    // Apply category filter
    if (category != null) {
      treks = treks.where((trek) => trek.category == category).toList();
    }
    
    // Filter by public
    treks = treks.where((trek) => trek.isPublic).toList();
    
    // Calculate distances and filter by radius
    final treksWithDistance = <MapEntry<Trek, double>>[];
    for (final trek in treks) {
      double? trekLat, trekLng;
      
      if (trek.location != null) {
        trekLat = trek.location!.geopoint.latitude;
        trekLng = trek.location!.geopoint.longitude;
      } else if (trek.startPoint != null) {
        trekLat = trek.startPoint!.latitude;
        trekLng = trek.startPoint!.longitude;
      }
      
      if (trekLat != null && trekLng != null) {
        final distance = GeoUtils.calculateDistance(
          latitude, longitude, trekLat, trekLng,
        );
        if (distance <= radiusKm) {
          treksWithDistance.add(MapEntry(trek, distance));
        }
      }
    }
    
    // Sort by distance (closest first)
    treksWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    // If no results from geohash query, fallback to full collection scan
    if (treksWithDistance.isEmpty) {
      return _getTreksNearLocationFallback(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        category: category,
        limit: limit,
      );
    }
    
    return treksWithDistance.take(limit).map((e) => e.key).toList();
  }

  /// Fallback method when geohash fields are not populated
  Future<List<Trek>> _getTreksNearLocationFallback({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    TrekCategory? category,
    int limit = 20,
  }) async {
    debugPrint('Using fallback nearby treks method - fetching all treks');
    final treks = await getTreks(category: category, limit: 100);
    debugPrint('Fallback: Got ${treks.length} treks to filter');
    
    final nearbyTreks = <MapEntry<Trek, double>>[];
    for (final trek in treks) {
      double? trekLat, trekLng;
      
      if (trek.location != null) {
        trekLat = trek.location!.geopoint.latitude;
        trekLng = trek.location!.geopoint.longitude;
      } else if (trek.startPoint != null) {
        trekLat = trek.startPoint!.latitude;
        trekLng = trek.startPoint!.longitude;
      }
      
      if (trekLat != null && trekLng != null && trekLat != 0 && trekLng != 0) {
        final distance = GeoUtils.calculateDistance(
          latitude, longitude, trekLat, trekLng,
        );
        debugPrint('Trek "${trek.title}" is ${distance.toStringAsFixed(1)}km away');
        if (distance <= radiusKm) {
          nearbyTreks.add(MapEntry(trek, distance));
        }
      } else {
        debugPrint('Trek "${trek.title}" has no valid location data');
      }
    }
    
    debugPrint('Fallback: Found ${nearbyTreks.length} nearby treks within ${radiusKm}km');
    nearbyTreks.sort((a, b) => a.value.compareTo(b.value));
    return nearbyTreks.take(limit).map((e) => e.key).toList();
  }

  /// Stream treks near a location for real-time updates
  /// This enables dynamic updates when nearby treks change
  Stream<List<Trek>> streamTreksNearLocation({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    TrekCategory? category,
    int limit = 20,
  }) {
    final precision = GeoUtils.getGeohashPrecisionForRadius(radiusKm);
    final centerGeohash = GeoUtils.encodeGeohash(latitude, longitude, precision: precision);
    final neighbors = GeoUtils.getGeohashNeighbors(centerGeohash);
    final geohashesToQuery = [centerGeohash, ...neighbors];
    
    // Create streams for all geohash prefixes
    final streams = geohashesToQuery.map((prefix) {
      final upperBound = prefix.substring(0, prefix.length - 1) + 
          String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);
      
      return _treksCollection
          .where('location.geohash', isGreaterThanOrEqualTo: prefix)
          .where('location.geohash', isLessThan: upperBound)
          .limit(limit)
          .snapshots()
          .map((snapshot) => 
              snapshot.docs.map((doc) => Trek.fromFirestore(doc)).toList())
          .handleError((_) => <Trek>[]);
    }).toList();
    
    // If no geohash streams work, fallback to full collection
    if (streams.isEmpty) {
      return _streamTreksNearLocationFallback(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        category: category,
        limit: limit,
      );
    }
    
    // Combine all streams
    return _combineStreams(streams).map((trekLists) {
      // Merge results and remove duplicates
      final trekMap = <String, Trek>{};
      for (final trekList in trekLists) {
        for (final trek in trekList) {
          trekMap[trek.id] = trek;
        }
      }
      
      var treks = trekMap.values.toList();
      
      // Apply filters
      if (category != null) {
        treks = treks.where((trek) => trek.category == category).toList();
      }
      treks = treks.where((trek) => trek.isPublic).toList();
      
      // Filter and sort by distance
      final treksWithDistance = <MapEntry<Trek, double>>[];
      for (final trek in treks) {
        double? trekLat, trekLng;
        
        if (trek.location != null) {
          trekLat = trek.location!.geopoint.latitude;
          trekLng = trek.location!.geopoint.longitude;
        } else if (trek.startPoint != null) {
          trekLat = trek.startPoint!.latitude;
          trekLng = trek.startPoint!.longitude;
        }
        
        if (trekLat != null && trekLng != null) {
          final distance = GeoUtils.calculateDistance(
            latitude, longitude, trekLat, trekLng,
          );
          if (distance <= radiusKm) {
            treksWithDistance.add(MapEntry(trek, distance));
          }
        }
      }
      
      treksWithDistance.sort((a, b) => a.value.compareTo(b.value));
      return treksWithDistance.take(limit).map((e) => e.key).toList();
    });
  }

  /// Fallback stream when geohash fields are not populated
  Stream<List<Trek>> _streamTreksNearLocationFallback({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    TrekCategory? category,
    int limit = 20,
  }) {
    return streamTreks(category: category, limit: 100).map((treks) {
      final nearbyTreks = <MapEntry<Trek, double>>[];
      
      for (final trek in treks) {
        double? trekLat, trekLng;
        
        if (trek.location != null) {
          trekLat = trek.location!.geopoint.latitude;
          trekLng = trek.location!.geopoint.longitude;
        } else if (trek.startPoint != null) {
          trekLat = trek.startPoint!.latitude;
          trekLng = trek.startPoint!.longitude;
        }
        
        if (trekLat != null && trekLng != null) {
          final distance = GeoUtils.calculateDistance(
            latitude, longitude, trekLat, trekLng,
          );
          if (distance <= radiusKm) {
            nearbyTreks.add(MapEntry(trek, distance));
          }
        }
      }
      
      nearbyTreks.sort((a, b) => a.value.compareTo(b.value));
      return nearbyTreks.take(limit).map((e) => e.key).toList();
    });
  }

  /// Combine multiple streams into one
  Stream<List<List<Trek>>> _combineStreams(List<Stream<List<Trek>>> streams) {
    if (streams.isEmpty) return Stream.value([]);
    if (streams.length == 1) return streams.first.map((list) => [list]);
    
    return streams.first.asyncExpand((firstList) {
      return _combineStreams(streams.skip(1).toList()).map((otherLists) {
        return [firstList, ...otherLists];
      });
    });
  }

  /// Calculate distance between user and a trek
  double getDistanceToTrek(double userLat, double userLng, Trek trek) {
    double? trekLat, trekLng;
    
    if (trek.location != null) {
      trekLat = trek.location!.geopoint.latitude;
      trekLng = trek.location!.geopoint.longitude;
    } else if (trek.startPoint != null) {
      trekLat = trek.startPoint!.latitude;
      trekLng = trek.startPoint!.longitude;
    }
    
    if (trekLat == null || trekLng == null) return double.infinity;
    
    return GeoUtils.calculateDistance(userLat, userLng, trekLat, trekLng);
  }
}
