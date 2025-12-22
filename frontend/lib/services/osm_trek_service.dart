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
    // Cap radius to 100km to avoid API timeouts and excessive data
    final effectiveRadius = radiusKm > 100 ? 100.0 : radiusKm;
    final cacheKey = _getCacheKey(latitude, longitude, effectiveRadius);
    
    if (!forceRefresh && _pathsCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      var cached = _pathsCache[cacheKey]!;
      if (specificCategory != null) {
        cached = cached.where((t) => t.category == specificCategory).toList();
      }
      debugPrint('OSM: Returning ${cached.length} cached path locations');
      return cached;
    }

    final radiusMeters = (effectiveRadius * 1000).toInt();
    // Use 'out center' for faster results - we don't need full geometry for listing
    final query = '''
[out:json][timeout:15];
(
  way["highway"="footway"]["name"](around:$radiusMeters,$latitude,$longitude);
  way["highway"="path"]["name"](around:$radiusMeters,$latitude,$longitude);
  way["highway"="track"]["name"](around:$radiusMeters,$latitude,$longitude);
  way["highway"="cycleway"]["name"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="park"](around:$radiusMeters,$latitude,$longitude);
  way["leisure"="nature_reserve"](around:$radiusMeters,$latitude,$longitude);
  way["natural"="wood"]["name"](around:$radiusMeters,$latitude,$longitude);
  node["leisure"="park"](around:$radiusMeters,$latitude,$longitude);
  node["natural"="peak"](around:$radiusMeters,$latitude,$longitude);
  node["tourism"="viewpoint"](around:$radiusMeters,$latitude,$longitude);
  relation["route"="hiking"](around:$radiusMeters,$latitude,$longitude);
  relation["route"="foot"](around:$radiusMeters,$latitude,$longitude);
);
out center;
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
    } else if (type == 'way' || type == 'relation') {
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
      
      // For relations, try to get bounds center if no center/geometry
      if (startPoint == null) {
        final bounds = element['bounds'] as Map<String, dynamic>?;
        if (bounds != null) {
          final minlat = bounds['minlat'] as num?;
          final maxlat = bounds['maxlat'] as num?;
          final minlon = bounds['minlon'] as num?;
          final maxlon = bounds['maxlon'] as num?;
          if (minlat != null && maxlat != null && minlon != null && maxlon != null) {
            startPoint = GeoPoint(
              latitude: (minlat + maxlat) / 2,
              longitude: (minlon + maxlon) / 2,
            );
          }
        }
      }
    }

    if (startPoint == null) return null;

    // Determine category
    final category = forceCategory ?? _determineCategory(tags);
    final difficulty = _determineDifficulty(tags, category);
    final estimatedTime = distance > 0 ? (distance / 83.3).round().clamp(5, 480) : 30;
    final imageUrl = _getCategoryImageUrl(category, tags);

    return Trek(
      id: 'osm_${element['id']}',
      title: name,
      description: _generateDescription(tags, category),
      imageUrl: imageUrl,
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
    if (highway == 'footway') return 'Jogging Path';
    if (highway == 'path') return 'Trail';
    if (highway == 'track') return 'Nature Track';
    if (highway == 'cycleway') return 'Cycling Path';
    
    // Hiking routes
    final route = tags['route'] as String?;
    if (route == 'hiking' || route == 'foot') return 'Hiking Trail';
    
    // Natural features
    if (natural == 'wood') return 'Forest';
    
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

    // Nature / jogging paths
    if (leisure == 'park' || leisure == 'nature_reserve' || highway == 'footway') {
      return TrekCategory.natureWalk;
    }

    // Default to nature/jogging
    return TrekCategory.natureWalk;
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
        parts.add('Nature area perfect for jogging and peaceful walks.');
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

  /// Generate an appropriate image URL based on category and tags
  /// Uses curated, professional images from Unsplash (direct URLs)
  String _getCategoryImageUrl(TrekCategory category, Map<String, dynamic> tags) {
    // Using direct Unsplash image URLs (not the deprecated source API)
    // These are curated, high-quality images relevant to each category
    
    final sport = tags['sport'] as String?;
    final leisure = tags['leisure'] as String?;
    final tourism = tags['tourism'] as String?;
    final natural = tags['natural'] as String?;
    final historic = tags['historic'] as String?;
    
    // Swimming pool - actual pool image
    if (sport == 'swimming' || category == TrekCategory.swimmingPool) {
      return 'https://images.unsplash.com/photo-1576610616656-d3aa5d1f4534?w=800&h=600&fit=crop';
    }
    
    // Yoga/wellness - meditation/yoga image
    if (sport == 'yoga' || category == TrekCategory.yogaCenter) {
      return 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800&h=600&fit=crop';
    }
    
    // Tennis court
    if (sport == 'tennis') {
      return 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=800&h=600&fit=crop';
    }
    
    // Basketball court
    if (sport == 'basketball') {
      return 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800&h=600&fit=crop';
    }
    
    // Soccer/football field
    if (sport == 'soccer' || sport == 'football') {
      return 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=600&fit=crop';
    }
    
    // Gym/fitness center
    if (sport == 'gym' || sport == 'fitness' || category == TrekCategory.gym || category == TrekCategory.fitnessCenter) {
      return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=600&fit=crop';
    }
    
    // Park - green park with trees
    if (leisure == 'park') {
      return 'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?w=800&h=600&fit=crop';
    }
    
    // Garden - botanical garden
    if (leisure == 'garden') {
      return 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800&h=600&fit=crop';
    }
    
    // Nature reserve - wildlife/forest
    if (leisure == 'nature_reserve') {
      return 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&h=600&fit=crop';
    }
    
    // Viewpoint - scenic overlook
    if (tourism == 'viewpoint') {
      return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop';
    }
    
    // Museum - museum building/interior
    if (tourism == 'museum') {
      return 'https://images.unsplash.com/photo-1554907984-15263bfd63bd?w=800&h=600&fit=crop';
    }
    
    // Tourist attraction
    if (tourism == 'attraction') {
      return 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800&h=600&fit=crop';
    }
    
    // Mountain peak
    if (natural == 'peak') {
      return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&h=600&fit=crop';
    }
    
    // Water/waterfall/river
    if (natural == 'water' || tags['waterway'] != null) {
      return 'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800&h=600&fit=crop';
    }
    
    // Historic monument
    if (historic != null) {
      return 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800&h=600&fit=crop';
    }
    
    // Category-based images with professional, relevant photos
    switch (category) {
      case TrekCategory.trekkingPoint:
        // Hiking trail in mountains
        return 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=800&h=600&fit=crop';
      case TrekCategory.natureWalk:
        // Nature path/jogging trail through forest
        return 'https://images.unsplash.com/photo-1476611317561-60117649dd94?w=800&h=600&fit=crop';
      case TrekCategory.cyclePath:
        // Cycling path with bike
        return 'https://images.unsplash.com/photo-1541625602330-2277a4c46182?w=800&h=600&fit=crop';
      case TrekCategory.pointOfInterest:
        // Landmark/scenic spot
        return 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&h=600&fit=crop';
      case TrekCategory.fitnessCenter:
        // Modern gym equipment
        return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=600&fit=crop';
      case TrekCategory.sportsClub:
        // Sports facility
        return 'https://images.unsplash.com/photo-1461896836934- voices08cbc?w=800&h=600&fit=crop';
      case TrekCategory.gym:
        // Gym with weights
        return 'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=800&h=600&fit=crop';
      case TrekCategory.swimmingPool:
        // Swimming pool
        return 'https://images.unsplash.com/photo-1576610616656-d3aa5d1f4534?w=800&h=600&fit=crop';
      case TrekCategory.yogaCenter:
        // Yoga practice
        return 'https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=800&h=600&fit=crop';
      case TrekCategory.artsCenter:
        // Art gallery/studio
        return 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=800&h=600&fit=crop';
    }
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
