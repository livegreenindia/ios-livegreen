import 'dart:math' as math;
import 'package:gpx/gpx.dart';
import '../models/trek.dart';

/// Utility class for parsing GPX files and calculating trek metrics
class GPXParser {
  /// Parse GPX string and extract trek data
  static GPXParseResult parseGPX(String gpxContent) {
    final gpx = GpxReader().fromString(gpxContent);
    
    final List<GeoPoint> points = [];
    final List<ElevationPoint> elevationProfile = [];
    
    double totalDistance = 0;
    double elevationGain = 0;
    double elevationLoss = 0;
    double minElevation = double.infinity;
    double maxElevation = double.negativeInfinity;
    
    GeoPoint? previousPoint;
    double cumulativeDistance = 0;
    
    // Process tracks
    for (final track in gpx.trks) {
      for (final segment in track.trksegs) {
        for (final point in segment.trkpts) {
          final geoPoint = GeoPoint(
            latitude: point.lat ?? 0,
            longitude: point.lon ?? 0,
            elevation: point.ele,
            timestamp: point.time,
          );
          points.add(geoPoint);
          
          // Calculate distance from previous point
          if (previousPoint != null) {
            final segmentDistance = calculateHaversineDistance(
              previousPoint.latitude,
              previousPoint.longitude,
              geoPoint.latitude,
              geoPoint.longitude,
            );
            totalDistance += segmentDistance;
            cumulativeDistance += segmentDistance;
          }
          
          // Track elevation
          if (point.ele != null) {
            final elevation = point.ele!;
            
            // Update min/max
            if (elevation < minElevation) minElevation = elevation;
            if (elevation > maxElevation) maxElevation = elevation;
            
            // Calculate gain/loss
            if (previousPoint?.elevation != null) {
              final elevDiff = elevation - previousPoint!.elevation!;
              if (elevDiff > 0) {
                elevationGain += elevDiff;
              } else {
                elevationLoss += elevDiff.abs();
              }
            }
            
            // Add to elevation profile (sample every ~100m)
            if (elevationProfile.isEmpty || 
                cumulativeDistance - (elevationProfile.last.distance) >= 100) {
              elevationProfile.add(ElevationPoint(
                distance: cumulativeDistance,
                elevation: elevation,
              ));
            }
          }
          
          previousPoint = geoPoint;
        }
      }
    }
    
    // Process routes (if no tracks)
    if (points.isEmpty) {
      for (final route in gpx.rtes) {
        for (final point in route.rtepts) {
          final geoPoint = GeoPoint(
            latitude: point.lat ?? 0,
            longitude: point.lon ?? 0,
            elevation: point.ele,
            timestamp: point.time,
          );
          points.add(geoPoint);
          
          if (previousPoint != null) {
            final segmentDistance = calculateHaversineDistance(
              previousPoint.latitude,
              previousPoint.longitude,
              geoPoint.latitude,
              geoPoint.longitude,
            );
            totalDistance += segmentDistance;
            cumulativeDistance += segmentDistance;
          }
          
          if (point.ele != null) {
            final elevation = point.ele!;
            if (elevation < minElevation) minElevation = elevation;
            if (elevation > maxElevation) maxElevation = elevation;
            
            if (previousPoint?.elevation != null) {
              final elevDiff = elevation - previousPoint!.elevation!;
              if (elevDiff > 0) {
                elevationGain += elevDiff;
              } else {
                elevationLoss += elevDiff.abs();
              }
            }
            
            if (elevationProfile.isEmpty || 
                cumulativeDistance - (elevationProfile.last.distance) >= 100) {
              elevationProfile.add(ElevationPoint(
                distance: cumulativeDistance,
                elevation: elevation,
              ));
            }
          }
          
          previousPoint = geoPoint;
        }
      }
    }
    
    // Process waypoints (if no tracks or routes)
    if (points.isEmpty) {
      for (final wpt in gpx.wpts) {
        final geoPoint = GeoPoint(
          latitude: wpt.lat ?? 0,
          longitude: wpt.lon ?? 0,
          elevation: wpt.ele,
          timestamp: wpt.time,
        );
        points.add(geoPoint);
        
        if (wpt.ele != null) {
          if (wpt.ele! < minElevation) minElevation = wpt.ele!;
          if (wpt.ele! > maxElevation) maxElevation = wpt.ele!;
        }
      }
    }
    
    // Handle edge cases
    if (minElevation == double.infinity) minElevation = 0;
    if (maxElevation == double.negativeInfinity) maxElevation = 0;
    
    // Add final elevation point
    if (elevationProfile.isNotEmpty && 
        points.isNotEmpty && 
        points.last.elevation != null) {
      elevationProfile.add(ElevationPoint(
        distance: totalDistance,
        elevation: points.last.elevation!,
      ));
    }
    
    // Get metadata
    final name = gpx.metadata?.name ?? 
        gpx.trks.firstOrNull?.name ?? 
        gpx.rtes.firstOrNull?.name ?? 
        'Imported Track';
    
    final description = gpx.metadata?.desc ?? 
        gpx.trks.firstOrNull?.desc ?? 
        gpx.rtes.firstOrNull?.desc ?? 
        '';
    
    return GPXParseResult(
      name: name,
      description: description,
      points: points,
      elevationProfile: elevationProfile,
      totalDistance: totalDistance,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      minElevation: minElevation,
      maxElevation: maxElevation,
      startPoint: points.isNotEmpty ? points.first : null,
      endPoint: points.length > 1 ? points.last : null,
    );
  }
  
  /// Calculate distance between two points using Haversine formula
  static double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) => degrees * math.pi / 180;
  
  /// Estimate walking time based on distance and elevation
  static int estimateWalkingTimeMinutes({
    required double distanceMeters,
    required double elevationGainMeters,
  }) {
    // Base speed: 5 km/h = 83.33 m/min
    const double baseSpeedMpm = 83.33;
    
    // Add 1 minute per 10m elevation gain (Naismith's rule adjustment)
    final elevationTimeMinutes = elevationGainMeters / 10;
    
    final baseTimeMinutes = distanceMeters / baseSpeedMpm;
    
    return (baseTimeMinutes + elevationTimeMinutes).ceil();
  }
  
  /// Simplify route points using Douglas-Peucker algorithm
  static List<GeoPoint> simplifyRoute(List<GeoPoint> points, double tolerance) {
    if (points.length <= 2) return points;
    
    // Find the point with the maximum distance from the line segment
    double maxDistance = 0;
    int maxIndex = 0;
    
    final start = points.first;
    final end = points.last;
    
    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }
    
    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      final left = simplifyRoute(points.sublist(0, maxIndex + 1), tolerance);
      final right = simplifyRoute(points.sublist(maxIndex), tolerance);
      
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [start, end];
    }
  }
  
  static double _perpendicularDistance(GeoPoint point, GeoPoint lineStart, GeoPoint lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;
    
    if (dx == 0 && dy == 0) {
      return calculateHaversineDistance(
        point.latitude,
        point.longitude,
        lineStart.latitude,
        lineStart.longitude,
      );
    }
    
    final t = ((point.longitude - lineStart.longitude) * dx + 
               (point.latitude - lineStart.latitude) * dy) / 
              (dx * dx + dy * dy);
    
    final nearestLon = lineStart.longitude + t * dx;
    final nearestLat = lineStart.latitude + t * dy;
    
    return calculateHaversineDistance(
      point.latitude,
      point.longitude,
      nearestLat,
      nearestLon,
    );
  }
  
  /// Generate GPX string from points
  static String generateGPX({
    required String name,
    required String description,
    required List<GeoPoint> points,
  }) {
    final gpx = Gpx();
    gpx.version = '1.1';
    gpx.creator = 'LiveGreen App';
    gpx.metadata = Metadata(
      name: name,
      desc: description,
      time: DateTime.now(),
    );
    
    final track = Trk(
      name: name,
      desc: description,
      trksegs: [
        Trkseg(
          trkpts: points.map((p) => Wpt(
            lat: p.latitude,
            lon: p.longitude,
            ele: p.elevation,
            time: p.timestamp,
          )).toList(),
        ),
      ],
    );
    
    gpx.trks.add(track);
    
    return GpxWriter().asString(gpx, pretty: true);
  }
  
  /// Calculate bearing between two points
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    var bearing = math.atan2(y, x);
    bearing = (bearing * 180 / math.pi + 360) % 360;
    
    return bearing;
  }
  
  /// Get compass direction from bearing
  static String getBearingDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}

/// Result from parsing a GPX file
class GPXParseResult {
  final String name;
  final String description;
  final List<GeoPoint> points;
  final List<ElevationPoint> elevationProfile;
  final double totalDistance;
  final double elevationGain;
  final double elevationLoss;
  final double minElevation;
  final double maxElevation;
  final GeoPoint? startPoint;
  final GeoPoint? endPoint;
  
  const GPXParseResult({
    required this.name,
    required this.description,
    required this.points,
    required this.elevationProfile,
    required this.totalDistance,
    required this.elevationGain,
    required this.elevationLoss,
    required this.minElevation,
    required this.maxElevation,
    this.startPoint,
    this.endPoint,
  });
  
  /// Convert to Trek model
  Trek toTrek({
    required String id,
    TrekCategory category = TrekCategory.walkingPath,
    TrekDifficulty? difficulty,
  }) {
    // Auto-determine difficulty based on distance and elevation
    final autoDifficulty = difficulty ?? _determineDifficulty();
    
    return Trek(
      id: id,
      title: name,
      description: description,
      distance: totalDistance,
      estimatedTimeMinutes: GPXParser.estimateWalkingTimeMinutes(
        distanceMeters: totalDistance,
        elevationGainMeters: elevationGain,
      ),
      difficulty: autoDifficulty,
      category: category,
      routePoints: points,
      elevationProfile: elevationProfile,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      minElevation: minElevation,
      maxElevation: maxElevation,
      startPoint: startPoint,
      endPoint: endPoint,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  TrekDifficulty _determineDifficulty() {
    // Based on distance and elevation gain
    final distanceKm = totalDistance / 1000;
    
    if (distanceKm < 5 && elevationGain < 200) {
      return TrekDifficulty.easy;
    } else if (distanceKm < 15 && elevationGain < 600) {
      return TrekDifficulty.moderate;
    } else if (distanceKm < 25 && elevationGain < 1200) {
      return TrekDifficulty.difficult;
    } else {
      return TrekDifficulty.expert;
    }
  }
}
