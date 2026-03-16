import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/trek.dart';

/// Google Places API service â€” all fetches run in parallel via Future.wait
/// so the UI gets results in 1â€“2 seconds instead of 30â€“60.
class GooglePlacesService {
  static const String _apiKey = 'AIzaSyA59STvjWZcL-k_gipSGBDV6u797zF0Q9M';
  static const String _nearbyUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String _textUrl =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';

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
      // Text Search returns formatted_address; Nearby Search returns vicinity
      description: (place['vicinity'] as String?) ??
          (place['formatted_address'] as String?) ??
          '',
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
      startPoint: GeoPoint(latitude: lat, longitude: lng),
      endPoint: GeoPoint(latitude: lat, longitude: lng),
      location: TrekLocation.fromGeoPoint(
          GeoPoint(latitude: lat, longitude: lng)),
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
      final status = data['status'] as String? ?? 'UNKNOWN';
      debugPrint('Google Places ($tag): ${(data['results'] as List?)?.length ?? 0} results  [$status]');
      if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
        debugPrint('  >> error_message: ${data['error_message']}');
      }
      final results = data['results'] as List? ?? [];
      final treks = <Trek>[];
      for (final place in results) {
        final t = _placeToTrek(place as Map<String, dynamic>, category, tag: tag);
        if (t != null) treks.add(t);
      }
      return treks;
    } catch (e) {
      debugPrint('Google Places error ($tag): $e');
      return [];
    }
  }

  /// Text Search fetch with automatic next_page_token pagination.
  /// [radiusMeters] is optional — when null, no radius is sent and Google
  /// returns the best matches globally biased by [latitude]/[longitude].
  /// When provided it acts as a soft location bias (NOT a hard cap like
  /// Nearby Search). Each page returns up to 20 results; max 3 pages = 60.
  Future<List<Trek>> _fetchText(
    String query,
    double latitude,
    double longitude,
    TrekCategory category,
    String tag, {
    int? radiusMeters,
  }) async {
    final treks = <Trek>[];
    String? nextPageToken;
    int page = 0;

    do {
      try {
        Uri uri;
        if (nextPageToken != null) {
          uri = Uri.parse('$_textUrl?pagetoken=$nextPageToken&key=$_apiKey');
        } else if (radiusMeters != null) {
          uri = Uri.parse(
              '$_textUrl?query=${Uri.encodeComponent(query)}'
              '&location=$latitude,$longitude'
              '&radius=$radiusMeters'
              '&key=$_apiKey');
        } else {
          // No radius — pure location-biased search, best for dense urban areas
          uri = Uri.parse(
              '$_textUrl?query=${Uri.encodeComponent(query)}'
              '&location=$latitude,$longitude'
              '&key=$_apiKey');
        }

        // Google requires ~2s before using a page token
        if (nextPageToken != null) {
          await Future.delayed(const Duration(seconds: 2));
        }

        final resp =
            await http.get(uri).timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) break;

        final data = json.decode(resp.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'UNKNOWN';
        final results = data['results'] as List? ?? [];
        debugPrint('Google Text Search ($tag) pg$page: ${results.length} results  status=[$status]');
        if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
          debugPrint('  >> error_message: ${data['error_message']}');
        }
        if (results.isEmpty) break; // no point paginating an empty page

        for (final place in results) {
          final t = _placeToTrek(
              place as Map<String, dynamic>, category,
              tag: tag);
          if (t != null) treks.add(t);
        }

        nextPageToken = data['next_page_token'] as String?;
        page++;
      } catch (e) {
        debugPrint('Google Text Search error ($tag) pg$page: $e');
        break;
      }
    } while (nextPageToken != null && page < 3); // max 3 pages = 60 results

    return treks;
  }

  // â”€â”€ public methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Fetch trekking / nature walk places â€” 3 parallel requests instead of 46.
  Future<List<Trek>> fetchTrekkingPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 100,
  }) async {
    final r = (radiusKm * 1000).toInt().clamp(0, 50000);

    final results = await Future.wait([
      // Hills, peaks, mountains, betta — natural climbing destinations
      _fetchText(
        'trekking hills mountains betta peak giri',
        latitude, longitude,
        TrekCategory.trekkingPoint, 'hills',
        radiusMeters: r,
      ),
      // Forts and hilltop heritage — most Indian trekking spots are forts
      _fetchText(
        'fort hilltop trek durga kota',
        latitude, longitude,
        TrekCategory.trekkingPoint, 'forts',
        radiusMeters: r,
      ),
      // Viewpoints and summits
      _fetchText(
        'viewpoint summit hiking trail trekking',
        latitude, longitude,
        TrekCategory.trekkingPoint, 'viewpoints',
        radiusMeters: r,
      ),
      // Nature walks — forests, wildlife, valley routes
      _fetchText(
        'nature walk forest valley waterfall wildlife reserve',
        latitude, longitude,
        TrekCategory.natureWalk, 'nature',
        radiusMeters: r,
      ),
      // Cycling paths and bike routes
      _fetchText(
        'cycling route bike path cycle track bicycle trail greenway',
        latitude, longitude,
        TrekCategory.cyclePath, 'cycling',
        radiusMeters: r,
      ),
    ]);

    final seen = <String>{};
    return results.expand((l) => l).where((t) => seen.add(t.id)).toList();
  }

  /// Fetch fitness places — 5 parallel Text Search queries WITHOUT a radius
  /// so Google returns the most-relevant matches biased by location rather
  /// than being capped at a fixed radius. Results typically cover 10–20 km.
  Future<List<Trek>> fetchFitnessPlaces({
    required double latitude,
    required double longitude,
  }) async {
    final results = await Future.wait([
      // Gyms and fitness centers
      _fetchText(
        'gym fitness center workout crossfit aerobics',
        latitude, longitude,
        TrekCategory.gym, 'gym',
      ),
      // Yoga, pilates, meditation studios
      _fetchText(
        'yoga studio yoga class meditation center pilates zumba',
        latitude, longitude,
        TrekCategory.yogaCenter, 'yoga',
      ),
      // Sports clubs — badminton, tennis, cricket, football
      _fetchText(
        'sports club badminton court tennis court cricket ground football',
        latitude, longitude,
        TrekCategory.sportsClub, 'sports',
      ),
      // Swimming pools
      _fetchText(
        'swimming pool aquatic center',
        latitude, longitude,
        TrekCategory.swimmingPool, 'swimming',
      ),
      // Dance, martial arts, wellness
      _fetchText(
        'dance studio martial arts boxing gymnasium wellness center',
        latitude, longitude,
        TrekCategory.artsCenter, 'arts',
      ),
    ]);

    final seen = <String>{};
    return results.expand((l) => l).where((t) => seen.add(t.id)).toList();
  }

  /// Fetch POI places – 3 parallel Nearby Search requests.
  Future<List<Trek>> fetchPOIPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    final r = (radiusKm * 1000).toInt();
    final base = '$_nearbyUrl?location=$latitude,$longitude&radius=$r';

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
