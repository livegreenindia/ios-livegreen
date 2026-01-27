import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/trek.dart';

class GooglePlacesService {
  static const String _apiKey = 'AIzaSyA59STvjWZcL-k_gipSGBDV6u797zF0Q9M';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  Future<List<Trek>> fetchTrekkingPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 100,
  }) async {
    final radiusMeters = (radiusKm * 1000).toInt();
    final keywords = [
      'trek', 'trekking', 'hill', 'mountain', 'forest', 'viewpoint', 'peak', 'nature', 'trail',
      'Nandi Hills', 'Shivagange', 'Turahalli', 'Skandagiri', 'Anthargange', 'Savandurga', 'Makalidurga', 'Ramanagara', 'Devarayanadurga', 'Kunti Betta', 'Madhugiri', 'Bilikal Rangaswamy Betta', 'Channarayana Durga', 'Kabbaladurga', 'Hutridurga', 'Avalabetta', 'Siddara Betta', 'Handi Gundi Betta', 'Gudibande Fort', 'Uttari Betta', 'Kumara Parvatha', 'Pushpagiri', 'Bandaje Falls', 'Ballalarayana Durga', 'Kodachadri', 'Kudremukh', 'Tadiandamol', 'Brahmagiri', 'Chembra Peak', 'Agumbe', 'Kemmangundi', 'Mullayanagiri', 'Bababudangiri', 'Yana', 'Yedakumeri', 'Jenukal Gudda', 'Sharavathi Valley', 'Kurinjal Peak', 'Kopatty', 'Nishani Motte', 'Charmadi Ghat', 'Sakleshpur', 'Bisle Ghat', 'Coorg', 'Chikmagalur', 'Western Ghats'
    ];
    final List<Trek> treks = [];
    for (final keyword in keywords) {
      final url = '$_baseUrl?location=$latitude,$longitude&radius=$radiusMeters&keyword=$keyword&type=point_of_interest&key=$_apiKey';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        log('Google Places API ($keyword) response: ${resp.body}');
        if (data['results'] is List) {
          for (final place in data['results']) {
            final name = place['name'] ?? '';
            final lat = place['geometry']?['location']?['lat'];
            final lng = place['geometry']?['location']?['lng'];
            if (name.isNotEmpty && lat != null && lng != null) {
              treks.add(Trek(
                id: 'gplace_${place['place_id']}',
                title: name,
                description: place['vicinity'] ?? '',
                imageUrl: place['photos'] != null && place['photos'].isNotEmpty
                  ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place['photos'][0]['photo_reference']}&key=$_apiKey'
                  : null,
                distance: 0, // Will be calculated in UI
                estimatedTimeMinutes: 30,
                difficulty: TrekDifficulty.moderate,
                category: TrekCategory.trekkingPoint,
                routePoints: [],
                elevationProfile: [],
                elevationGain: 0,
                elevationLoss: 0,
                minElevation: 0,
                maxElevation: 0,
                usersToday: 0,
                rating: (place['rating'] as num?)?.toDouble() ?? 0,
                reviewCount: place['user_ratings_total'] ?? 0,
                startPoint: GeoPoint(latitude: lat, longitude: lng),
                endPoint: GeoPoint(latitude: lat, longitude: lng),
                location: TrekLocation.fromGeoPoint(GeoPoint(latitude: lat, longitude: lng)),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isPublic: true,
                tags: [keyword],
              ));
            }
          }
        }
      }
    }
    // Remove duplicates by place_id
    final seen = <String>{};
    return treks.where((t) => seen.add(t.id)).toList();
  }

  Future<List<Trek>> fetchFitnessPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
  }) async {
    final radiusMeters = (radiusKm * 1000).toInt();
    final List<Trek> treks = [];
    
    // Define fitness types and their categories
    final queries = [
      {'type': 'gym', 'category': TrekCategory.gym},
      {'type': 'spa', 'keyword': 'yoga', 'category': TrekCategory.yogaCenter},
      {'keyword': 'swimming pool', 'category': TrekCategory.swimmingPool},
      {'keyword': 'sports club', 'category': TrekCategory.sportsClub},
      {'keyword': 'fitness center', 'category': TrekCategory.gym},
      {'keyword': 'sports center', 'category': TrekCategory.sportsClub},
    ];

    for (final query in queries) {
      final type = query['type'] as String?;
      final keyword = query['keyword'] as String?;
      final category = query['category'] as TrekCategory;
      
      String url;
      if (type != null) {
        url = '$_baseUrl?location=$latitude,$longitude&radius=$radiusMeters&type=$type&key=$_apiKey';
      } else if (keyword != null) {
        url = '$_baseUrl?location=$latitude,$longitude&radius=$radiusMeters&keyword=$keyword&key=$_apiKey';
      } else {
        continue;
      }

      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          log('Google Places API (fitness: ${type ?? keyword}) returned ${(data['results'] as List?)?.length ?? 0} results');
          
          if (data['results'] is List) {
            for (final place in data['results']) {
              final name = place['name'] ?? '';
              final lat = place['geometry']?['location']?['lat'];
              final lng = place['geometry']?['location']?['lng'];
              
              if (name.isNotEmpty && lat != null && lng != null) {
                treks.add(Trek(
                  id: 'gplace_${place['place_id']}',
                  title: name,
                  description: place['vicinity'] ?? '',
                  imageUrl: place['photos'] != null && place['photos'].isNotEmpty
                    ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place['photos'][0]['photo_reference']}&key=$_apiKey'
                    : null,
                  distance: 0,
                  estimatedTimeMinutes: 30,
                  difficulty: TrekDifficulty.easy,
                  category: category,
                  routePoints: [],
                  elevationProfile: [],
                  elevationGain: 0,
                  elevationLoss: 0,
                  minElevation: 0,
                  maxElevation: 0,
                  usersToday: 0,
                  rating: (place['rating'] as num?)?.toDouble() ?? 0,
                  reviewCount: place['user_ratings_total'] ?? 0,
                  startPoint: GeoPoint(latitude: lat, longitude: lng),
                  endPoint: GeoPoint(latitude: lat, longitude: lng),
                  location: TrekLocation.fromGeoPoint(GeoPoint(latitude: lat, longitude: lng)),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isPublic: true,
                  tags: [type ?? keyword ?? 'fitness'],
                ));
              }
            }
          }
        }
      } catch (e) {
        log('Error fetching from Google Places: $e');
      }
    }
    
    // Remove duplicates by place_id
    final seen = <String>{};
    final uniqueTreks = treks.where((t) => seen.add(t.id)).toList();
    log('Google Places API: Total ${uniqueTreks.length} unique fitness locations');
    return uniqueTreks;
  }

  Future<List<Trek>> fetchPOIPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    final radiusMeters = (radiusKm * 1000).toInt();
    final List<Trek> treks = [];
    
    // Define POI types and keywords
    final queries = [
      {'type': 'tourist_attraction', 'category': TrekCategory.pointOfInterest},
      {'type': 'museum', 'category': TrekCategory.pointOfInterest},
      {'type': 'park', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'temple', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'church', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'viewpoint', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'waterfall', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'lake', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'monument', 'category': TrekCategory.pointOfInterest},
      {'keyword': 'fort', 'category': TrekCategory.pointOfInterest},
    ];

    for (final query in queries) {
      final type = query['type'] as String?;
      final keyword = query['keyword'] as String?;
      final category = query['category'] as TrekCategory;
      
      String url;
      if (type != null) {
        url = '$_baseUrl?location=$latitude,$longitude&radius=$radiusMeters&type=$type&key=$_apiKey';
      } else if (keyword != null) {
        url = '$_baseUrl?location=$latitude,$longitude&radius=$radiusMeters&keyword=$keyword&key=$_apiKey';
      } else {
        continue;
      }

      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          log('Google Places API (POI: ${type ?? keyword}) returned ${(data['results'] as List?)?.length ?? 0} results');
          
          if (data['results'] is List) {
            for (final place in data['results']) {
              final name = place['name'] ?? '';
              final lat = place['geometry']?['location']?['lat'];
              final lng = place['geometry']?['location']?['lng'];
              
              if (name.isNotEmpty && lat != null && lng != null) {
                treks.add(Trek(
                  id: 'gplace_${place['place_id']}',
                  title: name,
                  description: place['vicinity'] ?? '',
                  imageUrl: place['photos'] != null && place['photos'].isNotEmpty
                    ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place['photos'][0]['photo_reference']}&key=$_apiKey'
                    : null,
                  distance: 0,
                  estimatedTimeMinutes: 30,
                  difficulty: TrekDifficulty.easy,
                  category: category,
                  routePoints: [],
                  elevationProfile: [],
                  elevationGain: 0,
                  elevationLoss: 0,
                  minElevation: 0,
                  maxElevation: 0,
                  usersToday: 0,
                  rating: (place['rating'] as num?)?.toDouble() ?? 0,
                  reviewCount: place['user_ratings_total'] ?? 0,
                  startPoint: GeoPoint(latitude: lat, longitude: lng),
                  endPoint: GeoPoint(latitude: lat, longitude: lng),
                  location: TrekLocation.fromGeoPoint(GeoPoint(latitude: lat, longitude: lng)),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isPublic: true,
                  tags: [type ?? keyword ?? 'poi'],
                ));
              }
            }
          }
        }
      } catch (e) {
        log('Error fetching POI from Google Places: $e');
      }
    }
    
    // Remove duplicates by place_id
    final seen = <String>{};
    final uniqueTreks = treks.where((t) => seen.add(t.id)).toList();
    log('Google Places API: Total ${uniqueTreks.length} unique POI locations');
    return uniqueTreks;
  }
}
