import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/trek.dart';

class GooglePlacesService {
  static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY'; // TODO: Replace with your key or load from config
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
}
