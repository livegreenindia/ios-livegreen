import 'dart:math' as math;

/// Geolocation utility class for distance calculations and geohash encoding
class GeoUtils {
  static const double _earthRadiusKm = 6371.0;
  
  // Geohash base32 characters
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  
  /// Calculate haversine distance between two points in kilometers
  /// Alias for calculateDistanceKm for backward compatibility
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) => calculateDistanceKm(lat1, lon1, lat2, lon2);
  
  /// Calculate haversine distance between two points in kilometers
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return _earthRadiusKm * c;
  }
  
  /// Calculate haversine distance between two points in meters
  static double calculateDistanceM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistanceKm(lat1, lon1, lat2, lon2) * 1000;
  }
  
  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Get optimal geohash precision for a given radius in kilometers
  /// Returns precision value 1-9 based on radius
  static int getGeohashPrecisionForRadius(double radiusKm) {
    if (radiusKm > 500) return 2;
    if (radiusKm > 100) return 3;
    if (radiusKm > 20) return 4;
    if (radiusKm > 5) return 5;
    if (radiusKm > 1) return 6;
    if (radiusKm > 0.15) return 7;
    if (radiusKm > 0.04) return 8;
    return 9;
  }
  
  /// Encode latitude/longitude to geohash with specified precision
  /// Precision 1-12, higher = more precise
  /// - 1: ~5000km
  /// - 4: ~39km  
  /// - 5: ~5km
  /// - 6: ~1.2km
  /// - 7: ~150m
  /// - 8: ~38m
  /// - 9: ~5m
  static String encodeGeohash(double latitude, double longitude, {int precision = 9}) {
    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    
    final buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;
    
    while (buffer.length < precision) {
      if (isEven) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      
      isEven = !isEven;
      
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    
    return buffer.toString();
  }
  
  /// Decode geohash to latitude/longitude bounds
  static Map<String, double> decodeGeohash(String geohash) {
    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    
    bool isEven = true;
    
    for (int i = 0; i < geohash.length; i++) {
      final ch = _base32.indexOf(geohash[i]);
      
      for (int bit = 4; bit >= 0; bit--) {
        if (isEven) {
          final mid = (lonMin + lonMax) / 2;
          if ((ch >> bit) & 1 == 1) {
            lonMin = mid;
          } else {
            lonMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2;
          if ((ch >> bit) & 1 == 1) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        isEven = !isEven;
      }
    }
    
    return {
      'latMin': latMin,
      'latMax': latMax,
      'lonMin': lonMin,
      'lonMax': lonMax,
      'lat': (latMin + latMax) / 2,
      'lon': (lonMin + lonMax) / 2,
    };
  }
  
  /// Get geohash neighbors (8 surrounding cells + center)
  static List<String> getGeohashNeighbors(String geohash) {
    if (geohash.isEmpty) return [];
    
    final bounds = decodeGeohash(geohash);
    final latDelta = (bounds['latMax']! - bounds['latMin']!) / 2;
    final lonDelta = (bounds['lonMax']! - bounds['lonMin']!) / 2;
    final lat = bounds['lat']!;
    final lon = bounds['lon']!;
    
    final neighbors = <String>[];
    
    // Center and 8 neighbors
    for (int dLat = -1; dLat <= 1; dLat++) {
      for (int dLon = -1; dLon <= 1; dLon++) {
        final neighborLat = lat + (dLat * latDelta * 2);
        final neighborLon = lon + (dLon * lonDelta * 2);
        
        if (neighborLat >= -90 && neighborLat <= 90 &&
            neighborLon >= -180 && neighborLon <= 180) {
          neighbors.add(encodeGeohash(neighborLat, neighborLon, 
              precision: geohash.length));
        }
      }
    }
    
    return neighbors.toSet().toList(); // Remove duplicates
  }
  
  /// Get geohash prefixes for a radius query
  /// Returns geohash prefixes that cover the given radius around a point
  static List<String> getGeohashesForRadius(
    double latitude, 
    double longitude, 
    double radiusKm,
  ) {
    // Determine precision based on radius
    int precision;
    if (radiusKm > 500) {
      precision = 2;
    } else if (radiusKm > 100) {
      precision = 3;
    } else if (radiusKm > 20) {
      precision = 4;
    } else if (radiusKm > 5) {
      precision = 5;
    } else if (radiusKm > 1) {
      precision = 6;
    } else {
      precision = 7;
    }
    
    final centerHash = encodeGeohash(latitude, longitude, precision: precision);
    return getGeohashNeighbors(centerHash);
  }
  
  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toInt()} m';
  }
  
  /// Format distance from kilometers
  static String formatDistanceKm(double km) {
    if (km < 1) {
      return '${(km * 1000).toInt()} m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.toInt()} km';
  }
  
  /// Check if a point is within a radius of another point
  static bool isWithinRadius(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusKm,
  ) {
    return calculateDistanceKm(lat1, lon1, lat2, lon2) <= radiusKm;
  }
  
  /// Calculate bearing between two points in degrees
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    
    final x = math.sin(dLon) * math.cos(lat2Rad);
    final y = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    final bearing = math.atan2(x, y);
    return (bearing * 180 / math.pi + 360) % 360;
  }
  
  /// Get cardinal direction from bearing
  static String getCardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
