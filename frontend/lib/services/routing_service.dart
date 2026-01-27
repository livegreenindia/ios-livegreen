import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/trek.dart';

/// Service for getting routing information between two points
class RoutingService {
  // Using OSRM (Open Source Routing Machine) - free and no API key needed
  static const String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Get route points between two coordinates
  /// Returns a list of GeoPoints representing the route
  Future<List<GeoPoint>> getRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      // Format: lng,lat;lng,lat (OSRM uses lng,lat format)
      final coordinates = '$startLng,$startLat;$endLng,$endLat';
      
      // Add geometries=geojson to get detailed route points
      final url = '$_osrmBaseUrl/$coordinates?geometries=geojson&overview=full';
      
      log('Routing service: Requesting route from ($startLat,$startLng) to ($endLat,$endLng)');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Routing service timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          log('Routing service: No routes found');
          // Fallback: return direct line
          return [
            GeoPoint(latitude: startLat, longitude: startLng),
            GeoPoint(latitude: endLat, longitude: endLng),
          ];
        }

        // Extract the first (best) route
        final route = data['routes'][0];
        final geometry = route['geometry']['coordinates'] as List;
        
        log('Routing service: Got route with ${geometry.length} points');

        // Convert from [lng, lat] to GeoPoint(lat, lng)
        final routePoints = geometry
            .map((coord) => GeoPoint(
                  latitude: (coord[1] as num).toDouble(),
                  longitude: (coord[0] as num).toDouble(),
                ))
            .toList();

        return routePoints;
      } else {
        log('Routing service error: ${response.statusCode} - ${response.body}');
        // Fallback: return direct line
        return [
          GeoPoint(latitude: startLat, longitude: startLng),
          GeoPoint(latitude: endLat, longitude: endLng),
        ];
      }
    } catch (e) {
      log('Routing service exception: $e');
      // Fallback: return direct line
      return [
        GeoPoint(latitude: startLat, longitude: startLng),
        GeoPoint(latitude: endLat, longitude: endLng),
      ];
    }
  }

  /// Get route between two GeoPoints
  Future<List<GeoPoint>> getRouteFromPoints(GeoPoint start, GeoPoint end) {
    return getRoute(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Get distance in meters between two coordinates using OSRM
  Future<double?> getDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final coordinates = '$startLng,$startLat;$endLng,$endLat';
      final url = '$_osrmBaseUrl/$coordinates';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final distance = data['routes'][0]['distance'] as num?;
          return distance?.toDouble();
        }
      }
      return null;
    } catch (e) {
      log('Routing service distance error: $e');
      return null;
    }
  }

  /// Get duration in seconds between two coordinates using OSRM
  Future<double?> getDuration(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final coordinates = '$startLng,$startLat;$endLng,$endLat';
      final url = '$_osrmBaseUrl/$coordinates';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final duration = data['routes'][0]['duration'] as num?;
          return duration?.toDouble();
        }
      }
      return null;
    } catch (e) {
      log('Routing service duration error: $e');
      return null;
    }
  }
}
