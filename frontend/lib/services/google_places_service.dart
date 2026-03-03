import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/trek.dart';

/// Google Places API service â€” all fetches run in parallel via Future.wait
/// so the UI gets results in 1â€“2 seconds instead of 30â€“60.
class GooglePlacesService {
  static const String _apiKey = 'AIzaSyA59STvjWZcL-k_gipSGBDV6u797zF0Q9M';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Trek? _placeToTrek(
    Map<String, dynamic> place,
    TrekCategory category, {
    String tag = '',
  }) {
    final name = place['name'] as String? ?? '';
    final lat = place['geometry']?['location']?['lat'];
    final lng = place['geometry']?['location']?['lng'];
    if (name.isEmpty || lat == null || lng == null) return null;

    return Trek(
      id: 'gplace_${place['place_id']}',
      title: name,
      description: place['vicinity'] as String? ?? '',
      imageUrl: (place['photos'] as List?)?.isNotEmpty == true
          ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400'
              '&photoreference=${place['photos'][0]['photo_reference']}'
              '&key=$_apiKey'
          : null,
      distance: 0,
      estimatedTimeMinutes: 30,
      difficulty: TrekDifficulty.moderate,
      category: category,
      routePoints: [],
      elevationProfile: [],
      elevationGain: 0,
      elevationLoss: 0,
      minElevation: 0,
      maxElevation: 0,
      usersToday: 0,
      rating: (place['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (place['user_ratings_total'] as num?)?.toInt() ?? 0,
      startPoint: GeoPoint(latitude: lat as double, longitude: lng as double),
      endPoint: GeoPoint(latitude: lat as double, longitude: lng as double),
      location: TrekLocation.fromGeoPoint(
          GeoPoint(latitude: lat as double, longitude: lng as double)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPublic: true,
      tags: tag.isNotEmpty ? [tag] : [],
    );
  }

  Future<List<Trek>> _fetch(
    String url,
    TrekCategory category,
    String tag,
  ) async {
    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body) as Map<String, dynamic>;
      log('Google Places ($tag): ${(data['results'] as List?)?.length ?? 0} results');
      final results = data['results'] as List? ?? [];
      final treks = <Trek>[];
      for (final place in results) {
        final t = _placeToTrek(place as Map<String, dynamic>, category, tag: tag);
        if (t != null) treks.add(t);
      }
      return treks;
    } catch (e) {
      log('Google Places error ($tag): $e');
      return [];
    }
  }

  // â”€â”€ public methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Fetch trekking / nature walk places â€” 3 parallel requests instead of 46.
  Future<List<Trek>> fetchTrekkingPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    final r = (radiusKm * 1000).toInt();
    final base = '$_baseUrl?location=$latitude,$longitude&radius=$r';

    final results = await Future.wait([
      // Hills, peaks, mountains, betta — natural climbing destinations
      _fetch(
        '$base&type=natural_feature&keyword=hill+peak+mountain+betta+giri&key=$_apiKey',
        TrekCategory.trekkingPoint,
        'hills',
      ),
      // Forts and hilltop heritage — most Indian trekking spots are forts
      _fetch(
        '$base&type=point_of_interest&keyword=fort+durga+kota+hilltop+trek&key=$_apiKey',
        TrekCategory.trekkingPoint,
        'forts',
      ),
      // Viewpoints and summits
      _fetch(
        '$base&type=point_of_interest&keyword=viewpoint+summit+trekking+hiking+trail&key=$_apiKey',
        TrekCategory.trekkingPoint,
        'viewpoints',
      ),
      // Nature walks — forests, wildlife, valley routes
      _fetch(
        '$base&type=natural_feature&keyword=forest+valley+nature+walk+falls&key=$_apiKey',
        TrekCategory.natureWalk,
        'nature',
      ),
    ]);

    final seen = <String>{};
    return results.expand((l) => l).where((t) => seen.add(t.id)).toList();
  }

  /// Fetch fitness places â€” 4 parallel requests.
  Future<List<Trek>> fetchFitnessPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
  }) async {
    final r = (radiusKm * 1000).toInt();
    final base = '$_baseUrl?location=$latitude,$longitude&radius=$r';

    final results = await Future.wait([
      _fetch('$base&type=gym&key=$_apiKey', TrekCategory.gym, 'gym'),
      _fetch('$base&type=spa&keyword=yoga&key=$_apiKey', TrekCategory.yogaCenter, 'yoga'),
      _fetch('$base&type=stadium&key=$_apiKey', TrekCategory.sportsClub, 'sports'),
      _fetch('$base&keyword=swimming+pool&key=$_apiKey', TrekCategory.swimmingPool, 'swimming'),
    ]);

    final seen = <String>{};
    return results.expand((l) => l).where((t) => seen.add(t.id)).toList();
  }

  /// Fetch POI places â€” 3 parallel requests.
  Future<List<Trek>> fetchPOIPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    final r = (radiusKm * 1000).toInt();
    final base = '$_baseUrl?location=$latitude,$longitude&radius=$r';

    final results = await Future.wait([
      _fetch('$base&type=tourist_attraction&key=$_apiKey', TrekCategory.pointOfInterest, 'attraction'),
      _fetch('$base&type=museum&key=$_apiKey', TrekCategory.pointOfInterest, 'museum'),
      _fetch(
        '$base&keyword=temple+fort+viewpoint+waterfall&key=$_apiKey',
        TrekCategory.pointOfInterest,
        'poi',
      ),
    ]);

    final seen = <String>{};
    return results.expand((l) => l).where((t) => seen.add(t.id)).toList();
  }
}
