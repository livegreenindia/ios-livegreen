import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/trek.dart';
import '../utils/geo_utils.dart';

/// Service to fetch real-world locations from OpenStreetMap via Overpass API
/// Automatically discovers gyms, yoga centers, POIs, trails, etc. based on user location
class OSMTrekService {
  static final OSMTrekService _instance = OSMTrekService._internal();
  factory OSMTrekService() => _instance;
  OSMTrekService._internal();

  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const Duration _timeout = Duration(seconds: 20);

  // Separate caches for each category type
  final Map<String, List<Trek>> _fitnessCache = {};
  final Map<String, List<Trek>> _poiCache = {};
  final Map<String, List<Trek>> _pathsCache = {};
  DateTime? _lastFetchTime;
  String? _lastFetchLocation;
  final Duration _cacheExpiry = const Duration(minutes: 15);

  String _getCacheKey(double lat, double lng, double radiusKm) {
    return '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}_$radiusKm';
  }

  bool _isCacheValid(String cacheKey) {
    if (_lastFetchTime == null || _lastFetchLocation != cacheKey) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheExpiry;
  }

  /// Fetch FITNESS locations (Gyms, Yoga, Sports Centers, Swimming Pools)
  Future<List<Trek>> fetchFitnessLocations({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
    TrekCategory? specificCategory,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(latitude, longitude, radiusKm);
    
    if (!forceRefresh && _fitnessCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      var cached = _fitnessCache[cacheKey]!;
      if (specificCategory != null) {
        cached = cached.where((t) => t.category == specificCategory).toList();
      }
      debugPrint('OSM: Returning ${cached.length} cached fitness locations');
      return cached;
    }

    final radiusMeters = (radiusKm * 1000).toInt();
    final query = '''
[out:json][timeout:15];
(
  node["leisure"="fitness_centre"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="sports_centre"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="sports_club"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="swimming_pool"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="fitness_station"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="gym"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="arts_centre"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="community_centre"](around:$radiusMeters,$latitude,$longitude);
  node["sport"="yoga"](around:$radiusMeters,$latitude,$longitude);
  node["sport"="fitness"](around:$radiusMeters,$latitude,$longitude);
  node["sport"="swimming"](around:$radiusMeters,$latitude,$longitude);
  node["sport"="multi"](around:$radiusMeters,$latitude,$longitude);
  node["club"="sport"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="fitness_centre"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="sports_centre"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="swimming_pool"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="gym"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="arts_centre"](around:$radiusMeters,$latitude,$longitude);
);
out center;
''';

    try {
      // Pass null to let _determineCategory assign the right fitness sub-category
      final treks = await _executeQuery(query, latitude, longitude, null);
      _fitnessCache[cacheKey] = treks;
      _lastFetchTime = DateTime.now();
      _lastFetchLocation = cacheKey;
      
      var result = treks;
      if (specificCategory != null) {
        result = treks.where((t) => t.category == specificCategory).toList();
      }
      debugPrint('OSM: Fetched ${result.length} fitness locations (total cached: ${treks.length})');
      return result;
    } catch (e) {
      debugPrint('OSM Fitness error: $e');
      return _fitnessCache[cacheKey] ?? [];
    }
  }

  /// Fetch POINTS OF INTEREST (Viewpoints, Temples, Museums, Historic sites)
  Future<List<Trek>> fetchPOILocations({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(latitude, longitude, radiusKm);
    
    if (!forceRefresh && _poiCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      debugPrint('OSM: Returning ${_poiCache[cacheKey]!.length} cached POI locations');
      return _poiCache[cacheKey]!;
    }

    final radiusMeters = (radiusKm * 1000).toInt();
    final query = '''
[out:json][timeout:15];
(
  node["tourism"="viewpoint"](around:$radiusMeters,$latitude,$longitude);
  node["tourism"="attraction"](around:$radiusMeters,$latitude,$longitude);
  node["tourism"="museum"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="place_of_worship"](around:$radiusMeters,$latitude,$longitude);
  node["amenity"="theatre"](around:$radiusMeters,$latitude,$longitude);
  node["historic"](around:$radiusMeters,$latitude,$longitude);
  node["natural"="peak"](around:$radiusMeters,$latitude,$longitude);
  node["waterway"="waterfall"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="garden"](around:$radiusMeters,$latitude,$longitude);
  way["tourism"="attraction"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="garden"](around:$radiusMeters,$latitude,$longitude);
);
out center;
''';

    try {
      final treks = await _executeQuery(query, latitude, longitude, TrekCategory.pointOfInterest);
      _poiCache[cacheKey] = treks;
      _lastFetchTime = DateTime.now();
      _lastFetchLocation = cacheKey;
      debugPrint('OSM: Fetched ${treks.length} POI locations');
      return treks;
    } catch (e) {
      debugPrint('OSM POI error: $e');
      return _poiCache[cacheKey] ?? [];
    }
  }

  /// Fetch PATHS (Walking, Trekking, Nature, Cycling)
  Future<List<Trek>> fetchPathLocations({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    TrekCategory? specificCategory,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(latitude, longitude, radiusKm);
    
    if (!forceRefresh && _pathsCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      var cached = _pathsCache[cacheKey]!;
      if (specificCategory != null) {
        cached = cached.where((t) => t.category == specificCategory).toList();
      }
      debugPrint('OSM: Returning ${cached.length} cached path locations');
      return cached;
    }

    final radiusMeters = (radiusKm * 1000).toInt();
    final query = '''
[out:json][timeout:15];
(
  way["highway"="footway"](around:$radiusMeters,$latitude,$longitude);
  way["highway"="path"](around:$radiusMeters,$latitude,$longitude);
  way["highway"="track"](around:$radiusMeters,$latitude,$longitude);
  way["highway"="cycleway"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="park"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="nature_reserve"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="park"](around:$radiusMeters,$latitude,$longitude);
);
out body geom;
''';

    try {
      final treks = await _executeQuery(query, latitude, longitude, null);
      _pathsCache[cacheKey] = treks;
      _lastFetchTime = DateTime.now();
      _lastFetchLocation = cacheKey;
      
      var result = treks;
      if (specificCategory != null) {
        result = treks.where((t) => t.category == specificCategory).toList();
      }
      debugPrint('OSM: Fetched ${result.length} path locations (total cached: ${treks.length})');
      return result;
    } catch (e) {
      debugPrint('OSM Paths error: $e');
      return _pathsCache[cacheKey] ?? [];
    }
  }

  /// Execute Overpass query and parse results
  Future<List<Trek>> _executeQuery(
    String query,
    double userLat,
    double userLng,
    TrekCategory? forceCategory,
  ) async {
    final response = await http.post(
      Uri.parse(_overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'data': query},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Overpass API error: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    final treks = <Trek>[];
    final seenNames = <String>{};

    for (final element in elements) {
      try {
        final trek = _parseElement(element, userLat, userLng, forceCategory);
        if (trek != null) {
          // Use location as unique key to avoid duplicates
          final key = '${trek.title}_${trek.startPoint?.latitude.toStringAsFixed(4)}';
          if (!seenNames.contains(key)) {
            seenNames.add(key);
            treks.add(trek);
          }
        }
      } catch (e) {
        // Skip invalid elements
      }
    }

    // Sort by distance
    treks.sort((a, b) {
      final distA = _getDistance(a, userLat, userLng);
      final distB = _getDistance(b, userLat, userLng);
      return distA.compareTo(distB);
    });

    return treks.take(50).toList();
  }

  double _getDistance(Trek trek, double userLat, double userLng) {
    if (trek.startPoint != null) {
      return GeoUtils.calculateDistance(
        userLat, userLng,
        trek.startPoint!.latitude, trek.startPoint!.longitude,
      );
    }
    return double.infinity;
  }

  Trek? _parseElement(
    Map<String, dynamic> element,
    double userLat,
    double userLng,
    TrekCategory? forceCategory,
  ) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final type = element['type'] as String?;

    // Get name
    String? name = tags['name'] as String? ?? 
                   tags['description'] as String? ??
                   _generateName(tags);
    if (name == null || name.isEmpty) return null;

    // Get coordinates
    GeoPoint? startPoint;
    List<GeoPoint> routePoints = [];
    double distance = 0;

    if (type == 'node') {
      final lat = element['lat'] as double?;
      final lon = element['lon'] as double?;
      if (lat != null && lon != null) {
        startPoint = GeoPoint(latitude: lat, longitude: lon);
      }
    } else if (type == 'way') {
      // Check for center coordinates first
      final center = element['center'] as Map<String, dynamic>?;
      if (center != null) {
        startPoint = GeoPoint(
          latitude: (center['lat'] as num).toDouble(),
          longitude: (center['lon'] as num).toDouble(),
        );
      }
      // Get geometry for route
      final geometry = element['geometry'] as List<dynamic>?;
      if (geometry != null && geometry.isNotEmpty) {
        routePoints = geometry.map((g) {
          return GeoPoint(
            latitude: (g['lat'] as num).toDouble(),
            longitude: (g['lon'] as num).toDouble(),
          );
        }).toList();
        startPoint ??= routePoints.first;
        distance = _calculateRouteDistance(routePoints);
      }
    }

    if (startPoint == null) return null;

    // Determine category
    final category = forceCategory ?? _determineCategory(tags);
    final difficulty = _determineDifficulty(tags, category);
    final estimatedTime = distance > 0 ? (distance / 83.3).round().clamp(5, 480) : 30;

    return Trek(
      id: 'osm_${element['id']}',
      title: name,
      description: _generateDescription(tags, category),
      imageUrl: null,
      distance: distance,
      estimatedTimeMinutes: estimatedTime,
      difficulty: difficulty,
      category: category,
      routePoints: routePoints,
      elevationProfile: [],
      elevationGain: 0,
      elevationLoss: 0,
      minElevation: 0,
      maxElevation: 0,
      usersToday: 0,
      rating: 0,
      reviewCount: 0,
      startPoint: startPoint,
      endPoint: routePoints.isNotEmpty ? routePoints.last : startPoint,
      location: TrekLocation.fromGeoPoint(startPoint),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPublic: true,
      tags: _extractTags(tags),
    );
  }

  String? _generateName(Map<String, dynamic> tags) {
    final sport = tags['sport'] as String?;
    final leisure = tags['leisure'] as String?;
    final amenity = tags['amenity'] as String?;
    final tourism = tags['tourism'] as String?;
    final historic = tags['historic'] as String?;
    final natural = tags['natural'] as String?;
    final highway = tags['highway'] as String?;

    if (sport == 'yoga') return 'Yoga Center';
    if (sport == 'swimming') return 'Swimming Pool';
    if (sport == 'fitness' || sport == 'gym') return 'Fitness Center';
    if (amenity == 'gym') return 'Gym';
    if (amenity == 'place_of_worship') {
      final religion = tags['religion'] as String?;
      return religion != null ? '${_capitalize(religion)} Temple' : 'Temple';
    }
    if (amenity == 'theatre') return 'Theatre';
    if (leisure == 'fitness_centre') return 'Fitness Center';
    if (leisure == 'sports_centre') return 'Sports Center';
    if (leisure == 'swimming_pool') return 'Swimming Pool';
    if (leisure == 'fitness_station') return 'Outdoor Gym';
    if (leisure == 'park') return 'Park';
    if (leisure == 'garden') return 'Garden';
    if (leisure == 'nature_reserve') return 'Nature Reserve';
    if (tourism == 'viewpoint') return 'Viewpoint';
    if (tourism == 'museum') return 'Museum';
    if (tourism == 'attraction') return 'Attraction';
    if (historic != null) return 'Historic ${_capitalize(historic.replaceAll('_', ' '))}';
    if (natural == 'peak') return 'Peak';
    if (tags['waterway'] == 'waterfall') return 'Waterfall';
    if (highway == 'footway') return 'Walking Path';
    if (highway == 'path') return 'Trail';
    if (highway == 'track') return 'Nature Track';
    if (highway == 'cycleway') return 'Cycling Path';
    
    return null;
  }

  TrekCategory _determineCategory(Map<String, dynamic> tags) {
    final highway = tags['highway'] as String?;
    final leisure = tags['leisure'] as String?;
    final sport = tags['sport'] as String?;
    final amenity = tags['amenity'] as String?;
    final tourism = tags['tourism'] as String?;
    final club = tags['club'] as String?;

    // Fitness sub-categories (check specific ones first)
    
    // Swimming Pool
    if (leisure == 'swimming_pool' || sport == 'swimming') {
      return TrekCategory.swimmingPool;
    }
    
    // Yoga Center
    if (sport == 'yoga') {
      return TrekCategory.yogaCenter;
    }
    
    // Arts Center
    if (amenity == 'arts_centre' || amenity == 'community_centre') {
      return TrekCategory.artsCenter;
    }
    
    // Gym
    if (amenity == 'gym' || leisure == 'fitness_station' || 
        leisure == 'fitness_centre' || sport == 'fitness' || sport == 'gym') {
      return TrekCategory.gym;
    }
    
    // Sports Club
    if (leisure == 'sports_centre' || leisure == 'sports_club' ||
        club == 'sport' || sport == 'multi') {
      return TrekCategory.sportsClub;
    }

    // POI
    if (tourism != null || amenity == 'place_of_worship' ||
        amenity == 'theatre' || tags['historic'] != null ||
        tags['natural'] == 'peak' || tags['waterway'] == 'waterfall' ||
        leisure == 'garden') {
      return TrekCategory.pointOfInterest;
    }

    // Cycling
    if (highway == 'cycleway' || tags['bicycle'] == 'designated') {
      return TrekCategory.cyclePath;
    }

    // Trekking
    if (highway == 'track' || tags['sac_scale'] != null) {
      return TrekCategory.trekkingPoint;
    }

    // Nature
    if (leisure == 'park' || leisure == 'nature_reserve') {
      return TrekCategory.natureWalk;
    }

    // Default walking
    return TrekCategory.walkingPath;
  }

  TrekDifficulty _determineDifficulty(Map<String, dynamic> tags, TrekCategory category) {
    if (category == TrekCategory.fitnessCenter || category == TrekCategory.pointOfInterest) {
      return TrekDifficulty.easy;
    }
    
    final sacScale = tags['sac_scale'] as String?;
    if (sacScale != null) {
      if (sacScale.contains('T1')) return TrekDifficulty.easy;
      if (sacScale.contains('T2')) return TrekDifficulty.moderate;
      return TrekDifficulty.difficult;
    }

    final surface = tags['surface'] as String?;
    if (surface == 'paved' || surface == 'asphalt') return TrekDifficulty.easy;
    
    return TrekDifficulty.moderate;
  }

  String _generateDescription(Map<String, dynamic> tags, TrekCategory category) {
    final parts = <String>[];
    
    switch (category) {
      case TrekCategory.fitnessCenter:
        final sport = tags['sport'] as String?;
        final leisure = tags['leisure'] as String?;
        if (sport == 'yoga') {
          parts.add('Yoga and meditation center. Perfect for wellness and flexibility.');
        } else if (sport == 'swimming' || leisure == 'swimming_pool') {
          parts.add('Swimming facility. Great for cardio and fitness.');
        } else if (leisure == 'fitness_station') {
          parts.add('Outdoor fitness station with free equipment.');
        } else {
          parts.add('Fitness center for workouts and training.');
        }
        break;
      case TrekCategory.pointOfInterest:
        final tourism = tags['tourism'] as String?;
        final amenity = tags['amenity'] as String?;
        if (tourism == 'viewpoint') {
          parts.add('Scenic viewpoint. Great for photos and relaxation.');
        } else if (tourism == 'museum') {
          parts.add('Museum. Explore history and culture.');
        } else if (amenity == 'place_of_worship') {
          parts.add('Place of worship. A spiritual destination.');
        } else if (tags['historic'] != null) {
          parts.add('Historic site worth exploring.');
        } else {
          parts.add('Interesting point of interest to visit.');
        }
        break;
      case TrekCategory.cyclePath:
        parts.add('Cycling path suitable for biking.');
        break;
      case TrekCategory.trekkingPoint:
        parts.add('Trekking trail for hiking enthusiasts.');
        break;
      case TrekCategory.natureWalk:
        parts.add('Nature area perfect for peaceful walks.');
        break;
      case TrekCategory.walkingPath:
        parts.add('Walking path for a pleasant stroll.');
        break;
      case TrekCategory.sportsClub:
        parts.add('Sports club for team activities and training.');
        break;
      case TrekCategory.gym:
        parts.add('Gym facility for strength and cardio workouts.');
        break;
      case TrekCategory.swimmingPool:
        parts.add('Swimming pool for aquatic fitness and recreation.');
        break;
      case TrekCategory.yogaCenter:
        parts.add('Yoga center for wellness, meditation and flexibility.');
        break;
      case TrekCategory.artsCenter:
        parts.add('Arts center for creative activities and expression.');
        break;
    }

    if (tags['opening_hours'] != null) {
      parts.add('Hours: ${tags['opening_hours']}');
    }
    if (tags['phone'] != null) {
      parts.add('📞 ${tags['phone']}');
    }

    return parts.join(' ');
  }

  List<String> _extractTags(Map<String, dynamic> tags) {
    final result = <String>[];
    for (final key in ['sport', 'amenity', 'leisure', 'tourism', 'historic', 'natural']) {
      if (tags[key] != null) result.add(tags[key] as String);
    }
    return result.take(5).toList();
  }

  double _calculateRouteDistance(List<GeoPoint> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += GeoUtils.calculateDistanceM(
        points[i].latitude, points[i].longitude,
        points[i + 1].latitude, points[i + 1].longitude,
      );
    }
    return total;
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  void clearCache() {
    _fitnessCache.clear();
    _poiCache.clear();
    _pathsCache.clear();
    _lastFetchTime = null;
    _lastFetchLocation = null;
  }
}
