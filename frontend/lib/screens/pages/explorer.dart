import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'dart:io';
import 'dart:async';

// Classes for storing all recordings and images
class RecordingEntry {
  final String audioPath;
  final String analysis;
  final String description;
  final DateTime timestamp;
  final LatLng location;
  final String category; // "Bird", "Human", "Unknown", etc.

  RecordingEntry({
    required this.audioPath,
    required this.analysis,
    required this.description,
    required this.timestamp,
    required this.location,
    required this.category,
  });
}

class ImageEntry {
  final String imagePath;
  final String analysis;
  final String description;
  final String habitat;
  final String behavior;
  final String conservation;
  final DateTime timestamp;
  final LatLng location;
  final String
      category; // "Bird", "Insect", "Plant", "Animal", "Human", "Unknown"

  ImageEntry({
    required this.imagePath,
    required this.analysis,
    required this.description,
    required this.habitat,
    required this.behavior,
    required this.conservation,
    required this.timestamp,
    required this.location,
    required this.category,
  });
}

// Global storage for captures
class GlobalCaptures {
  static List<RecordingEntry> allRecordings = [];
  static List<ImageEntry> allImages = [];
  static final List<VoidCallback> _listeners = [];

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  static void addRecording(RecordingEntry recording) {
    allRecordings.add(recording);
    _notifyListeners();
  }

  static void addImage(ImageEntry image) {
    allImages.add(image);
    _notifyListeners();
  }

  static void clearAll() {
    allRecordings.clear();
    allImages.clear();
    _notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ExplorePage(),
    const CollectionPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Custom App Bar with rounded bottom
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2D6A4F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.landscape, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'NatureLens AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Identify biodiversity with multi-stage AI reasoning.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),

                // Collection and Explore Tabs
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 0
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.explore,
                                color: _selectedIndex == 0
                                    ? const Color(0xFF2D6A4F)
                                    : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Explore',
                                style: TextStyle(
                                  color: _selectedIndex == 0
                                      ? const Color(0xFF2D6A4F)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 1
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.collections,
                                color: _selectedIndex == 1
                                    ? const Color(0xFF2D6A4F)
                                    : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Collection',
                                style: TextStyle(
                                  color: _selectedIndex == 1
                                      ? const Color(0xFF2D6A4F)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({Key? key}) : super(key: key);

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  // Storage for all captures (using global storage)
  List<RecordingEntry> get allRecordings => GlobalCaptures.allRecordings;
  List<ImageEntry> get allImages => GlobalCaptures.allImages;

  // Dynamic counts based on actual data
  int get birdsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'bird').length;
    count += allImages.where((i) => i.category.toLowerCase() == 'bird').length;
    return count;
  }

  int get insectsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'insect').length;
    count +=
        allImages.where((i) => i.category.toLowerCase() == 'insect').length;
    return count;
  }

  int get plantsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'plant').length;
    count += allImages.where((i) => i.category.toLowerCase() == 'plant').length;
    return count;
  }

  int get animalsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'animal').length;
    count +=
        allImages.where((i) => i.category.toLowerCase() == 'animal').length;
    return count;
  }

  // Get all discovery locations with categories
  List<Map<String, dynamic>> get discoveryLocations {
    List<Map<String, dynamic>> locations = [];

    // Add image discoveries
    for (var image in allImages) {
      // Add small offset to prevent overlap with current location marker
      final offsetLat = image.location.latitude + 0.0001; // Small north offset
      final offsetLng = image.location.longitude + 0.0001; // Small east offset

      locations.add({
        'location': LatLng(offsetLat, offsetLng),
        'category': image.category,
        'type': 'image',
        'timestamp': image.timestamp,
      });
      print(
          "Image discovery: ${image.category} at ${image.location.latitude}, ${image.location.longitude}");
    }

    // Add audio discoveries
    for (var recording in allRecordings) {
      // Add small offset to prevent overlap with current location marker
      final offsetLat =
          recording.location.latitude + 0.0001; // Small north offset
      final offsetLng =
          recording.location.longitude + 0.0001; // Small east offset

      locations.add({
        'location': LatLng(offsetLat, offsetLng),
        'category': recording.category,
        'type': 'audio',
        'timestamp': recording.timestamp,
      });
      print(
          "Audio discovery: ${recording.category} at ${recording.location.latitude}, ${recording.location.longitude}");
    }

    print("Total discoveries: ${locations.length}");
    return locations;
  }

  // Get category-specific icon
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bird':
        return Icons.flutter_dash;
      case 'insect':
        return Icons.bug_report;
      case 'plant':
        return Icons.local_florist;
      case 'animal':
        return Icons.pets;
      case 'human':
        return Icons.person;
      default:
        return Icons.help_outline;
    }
  }

  // Get category-specific color
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'bird':
        return const Color(0xFF1976D2); // Blue
      case 'insect':
        return const Color(0xFFE65100); // Orange
      case 'plant':
        return const Color(0xFF2E7D32); // Green
      case 'animal':
        return const Color(0xFF7B1FA2); // Purple
      case 'human':
        return const Color(0xFF424242); // Grey
      default:
        return const Color(0xFF757575); // Light grey
    }
  }

  LocationData? currentLocation;
  final Location location = Location();
  bool isLoadingLocation = true;
  StreamSubscription<LocationData>? locationSubscription;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getLocation();

    // Listen for global captures changes
    GlobalCaptures.addListener(_onGlobalCapturesChanged);
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    GlobalCaptures.removeListener(_onGlobalCapturesChanged);
    super.dispose();
  }

  // Map control functions
  void _zoomIn() {
    final currentZoom = mapController.camera.zoom;
    final newZoom = currentZoom + 1;
    // Limit maximum zoom to 18
    if (newZoom <= 18) {
      mapController.move(mapController.camera.center, newZoom);
    }
  }

  void _zoomOut() {
    final currentZoom = mapController.camera.zoom;
    final newZoom = currentZoom - 1;
    // Limit minimum zoom to 2
    if (newZoom >= 2) {
      mapController.move(mapController.camera.center, newZoom);
    }
  }

  void _centerOnCurrentLocation() {
    if (currentLocation != null) {
      mapController.move(
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        15.0,
      );
    }
  }

  void _onGlobalCapturesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh UI when captures are updated
    setState(() {});
  }

  Future<void> _getLocation() async {
    print("=== STARTING GPS LOCATION REQUEST ===");
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    try {
      print("Checking if location services are enabled...");
      // Check if location services are enabled
      serviceEnabled = await location.serviceEnabled();
      print("Location service enabled: $serviceEnabled");
      if (!serviceEnabled) {
        print("Requesting location service...");
        serviceEnabled = await location.requestService();
        print("Location service after request: $serviceEnabled");
        if (!serviceEnabled) {
          print("Location service not enabled - GPS required");
          setState(() {
            isLoadingLocation = false;
          });
          return;
        }
      }

      // Check location permissions
      var locationPermission = await ph.Permission.location.status;
      if (locationPermission.isDenied) {
        locationPermission = await ph.Permission.location.request();
        if (!locationPermission.isGranted) {
          print("Location permission denied - GPS required");
          setState(() {
            isLoadingLocation = false;
          });
          return;
        }
      }

      // Configure location settings for balanced accuracy
      await location.changeSettings(
        accuracy: LocationAccuracy.balanced,
        interval: 1000, // Update every 1 second
        distanceFilter: 5, // Update on 5+ meter movement
      );

      print("Requesting GPS location...");

      // Try multiple times to get GPS fix
      LocationData? locationData;
      for (int i = 0; i < 3; i++) {
        try {
          locationData = await location.getLocation();
          print(
              "GPS attempt ${i + 1}: Lat=${locationData.latitude}, Lon=${locationData.longitude}");

          if (locationData.latitude != null && locationData.longitude != null) {
            break; // Got valid location, stop trying
          }

          // Wait before retry
          await Future.delayed(Duration(milliseconds: 1000));
        } catch (e) {
          print("GPS attempt ${i + 1} failed: $e");
          await Future.delayed(Duration(milliseconds: 1000));
        }
      }

      if (locationData?.latitude != null && locationData?.longitude != null) {
        setState(() {
          currentLocation = locationData;
          isLoadingLocation = false;
          print("Location set successfully!");
        });
      } else {
        print("Failed to get location - trying network location as fallback");
        // Try network-based location as fallback
        try {
          await location.changeSettings(
            accuracy: LocationAccuracy.low,
            interval: 2000,
            distanceFilter: 10,
          );
          final fallbackLocation = await location.getLocation();
          if (fallbackLocation.latitude != null &&
              fallbackLocation.longitude != null) {
            setState(() {
              currentLocation = fallbackLocation;
              isLoadingLocation = false;
              print("Network location set as fallback!");
            });
          } else {
            print("All location methods failed");
            setState(() {
              isLoadingLocation = false;
            });
          }
        } catch (e) {
          print("Fallback location failed: $e");
          setState(() {
            isLoadingLocation = false;
          });
        }
      }

      // Start real-time location updates with GPS
      locationSubscription =
          location.onLocationChanged.listen((LocationData newLocation) {
        if (newLocation.latitude != null && newLocation.longitude != null) {
          if (mounted) {
            setState(() {
              currentLocation = newLocation;
            });
          }
        }
      });
    } catch (e) {
      print("GPS error: $e");
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  void _setDefaultLocation() {
    setState(() {
      isLoadingLocation = false;
      currentLocation = LocationData.fromMap({
        'latitude': 12.9716,
        'longitude': 77.5946,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          const SizedBox(height: 20),

          // Category Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        'BIRDS',
                        birdsCount,
                        Icons.flutter_dash,
                        const Color(0xFFE3F2FD),
                        const Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryCard(
                        'INSECTS',
                        insectsCount,
                        Icons.bug_report,
                        const Color(0xFFFFF3E0),
                        const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        'PLANTS',
                        plantsCount,
                        Icons.local_florist,
                        const Color(0xFFE8F5E9),
                        const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryCard(
                        'ANIMALS',
                        animalsCount,
                        Icons.pets,
                        const Color(0xFFF3E5F5),
                        const Color(0xFF7B1FA2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Global Discoveries
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.public,
                              color: Color(0xFF2D6A4F),
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Global Discoveries',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${plantsCount + animalsCount} Total',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: currentLocation != null
                                  ? LatLng(currentLocation!.latitude!,
                                      currentLocation!.longitude!)
                                  : LatLng(12.9716, 77.5946), // Default center
                              initialZoom: 15.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.naturelens',
                              ),
                              MarkerLayer(
                                markers: [
                                  // Current location marker
                                  if (currentLocation != null)
                                    Marker(
                                      width: 40.0,
                                      height: 40.0,
                                      point: LatLng(currentLocation!.latitude!,
                                          currentLocation!.longitude!),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.my_location,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  // GPS status indicator
                                  if (currentLocation == null &&
                                      !isLoadingLocation)
                                    Marker(
                                      width: 200.0,
                                      height: 60.0,
                                      point: LatLng(12.9716, 77.5946),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.gps_off,
                                                color: Colors.white, size: 20),
                                            Text('GPS Not Available',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Discovery markers with category-specific icons
                                  ...discoveryLocations.map((discovery) {
                                    return Marker(
                                      width: 40.0,
                                      height: 40.0,
                                      point: discovery['location'],
                                      child: Container(
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(
                                                discovery['category']),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(
                                                discovery['category']),
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ],
                          ),
                          // Loading indicator
                          if (isLoadingLocation)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Getting location...',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          else if (currentLocation != null)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: GestureDetector(
                                onTap: _centerOnCurrentLocation,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.my_location,
                                          color: Color(0xFF2D6A4F), size: 16),
                                      SizedBox(width: 4),
                                      Text('Your location',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Zoom Controls
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _zoomIn,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.add,
                                            size: 20, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    color: Colors.grey[300],
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _zoomOut,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.remove,
                                            size: 20, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // All Captures Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: Color(0xFF2D6A4F),
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'All Captures',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${allImages.length + allRecordings.length} Total',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Images Grid
                  if (allImages.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allImages.length,
                        itemBuilder: (context, index) {
                          final image = allImages[index];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      _showImageDetailsDialog(image);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(image.imagePath),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  image.category,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  image.analysis.length > 30
                                      ? '${image.analysis.substring(0, 30)}...'
                                      : image.analysis,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${image.timestamp.hour}:${image.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recordings List
                  if (allRecordings.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Audio Recordings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allRecordings.length,
                      itemBuilder: (context, index) {
                        final recording = allRecordings[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: recording.category == "Bird"
                                      ? Colors.orange[100]
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  recording.category == "Bird"
                                      ? Icons.flutter_dash
                                      : Icons.mic,
                                  size: 20,
                                  color: recording.category == "Bird"
                                      ? Colors.orange
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recording.category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (recording.description.isNotEmpty) ...[
                                      Text(
                                        recording.description.length > 30
                                            ? '${recording.description.substring(0, 30)}...'
                                            : recording.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      '${recording.timestamp.day}/${recording.timestamp.month}/${recording.timestamp.year} ${recording.timestamp.hour}:${recording.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (allImages.isEmpty && allRecordings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No captures yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Start capturing to see them here',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      String title, int count, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: iconColor,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: iconColor,
                letterSpacing: 0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Parse AI response into structured sections
  Map<String, String> _parseAIResponse(String response) {
    final Map<String, String> sections = {
      'description': '',
      'habitat': '',
      'behavior': '',
      'conservation': '',
    };

    final lines = response.split('\n');
    String? currentSection;

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('**DESCRIPTION**:')) {
        currentSection = 'description';
        sections['description'] =
            trimmedLine.replaceFirst('**DESCRIPTION**:', '').trim();
      } else if (trimmedLine.startsWith('**HABITAT**:')) {
        currentSection = 'habitat';
        sections['habitat'] =
            trimmedLine.replaceFirst('**HABITAT**:', '').trim();
      } else if (trimmedLine.startsWith('**BEHAVIOR**:')) {
        currentSection = 'behavior';
        sections['behavior'] =
            trimmedLine.replaceFirst('**BEHAVIOR**:', '').trim();
      } else if (trimmedLine.startsWith('**CONSERVATION**:')) {
        currentSection = 'conservation';
        sections['conservation'] =
            trimmedLine.replaceFirst('**CONSERVATION**:', '').trim();
      } else if (currentSection != null && trimmedLine.isNotEmpty) {
        sections[currentSection] =
            (sections[currentSection] ?? '') + ' ' + trimmedLine;
      }
    }

    // Clean up empty sections
    sections.forEach((key, value) {
      if (value.trim().isEmpty) {
        sections[key] = 'Information not available.';
      }
    });

    return sections;
  }

  Widget _buildSection(String title, IconData icon, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5F3F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D5F3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareImageDetails(ImageEntry image) async {
    try {
      // Create share text with all the structured information
      String shareText = '''🌿 NatureLens AI Discovery 🌿

📸 Category: ${image.category}

📝 Description:
${image.description.isNotEmpty ? image.description : _parseAIResponse(image.analysis)['description']!}

🏠 Habitat:
${image.habitat.isNotEmpty ? image.habitat : _parseAIResponse(image.analysis)['habitat']!}

🧠 Behavior:
${image.behavior.isNotEmpty ? image.behavior : _parseAIResponse(image.analysis)['behavior']!}

🌿 Conservation:
${image.conservation.isNotEmpty ? image.conservation : _parseAIResponse(image.analysis)['conservation']!}

📍 Location: ${image.location.latitude.toStringAsFixed(4)}, ${image.location.longitude.toStringAsFixed(4)}
📅 Date: ${image.timestamp.day}/${image.timestamp.month}/${image.timestamp.year}

🔬 Powered by Google Gemini AI
📱 NatureLens App''';

      // Share the text and image
      await Share.shareXFiles(
        [
          XFile(image.imagePath,
              name:
                  'naturelens_${image.category}_${image.timestamp.millisecondsSinceEpoch}.jpg')
        ],
        text: shareText,
        subject: 'NatureLens AI - ${image.category} Discovery',
      );
    } catch (e) {
      // Fallback to text-only sharing if image sharing fails
      try {
        String shareText = '''🌿 NatureLens AI Discovery 🌿

📸 Category: ${image.category}

📝 Description:
${image.description.isNotEmpty ? image.description : _parseAIResponse(image.analysis)['description']!}

🏠 Habitat:
${image.habitat.isNotEmpty ? image.habitat : _parseAIResponse(image.analysis)['habitat']!}

🧠 Behavior:
${image.behavior.isNotEmpty ? image.behavior : _parseAIResponse(image.analysis)['behavior']!}

🌿 Conservation:
${image.conservation.isNotEmpty ? image.conservation : _parseAIResponse(image.analysis)['conservation']!}

📍 Location: ${image.location.latitude.toStringAsFixed(4)}, ${image.location.longitude.toStringAsFixed(4)}
📅 Date: ${image.timestamp.day}/${image.timestamp.month}/${image.timestamp.year}

🔬 Powered by Google Gemini AI
📱 NatureLens App''';

        await Share.share(
          shareText,
          subject: 'NatureLens AI - ${image.category} Discovery',
        );
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to share image details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showImageDetailsDialog(ImageEntry image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Image.file(
                        File(image.imagePath),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Close button overlay
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    // Category badge overlay
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(image.category),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          image.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Analysis Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D5F3F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.psychology,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'AI Analysis',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D5F3F),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Description Section
                        _buildSection(
                            'Description',
                            Icons.description,
                            image.description.isNotEmpty
                                ? image.description
                                : _parseAIResponse(
                                    image.analysis)['description']!),
                        const SizedBox(height: 16),

                        // Habitat Section
                        _buildSection(
                            'Habitat',
                            Icons.home,
                            image.habitat.isNotEmpty
                                ? image.habitat
                                : _parseAIResponse(image.analysis)['habitat']!),
                        const SizedBox(height: 16),

                        // Behavior Section
                        _buildSection(
                            'Behavior',
                            Icons.psychology,
                            image.behavior.isNotEmpty
                                ? image.behavior
                                : _parseAIResponse(
                                    image.analysis)['behavior']!),
                        const SizedBox(height: 16),

                        // Conservation Section
                        _buildSection(
                            'Conservation',
                            Icons.eco,
                            image.conservation.isNotEmpty
                                ? image.conservation
                                : _parseAIResponse(
                                    image.analysis)['conservation']!),
                        const SizedBox(height: 24),

                        // Environment Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CAPTURE DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${image.timestamp.day}/${image.timestamp.month}/${image.timestamp.year} at ${image.timestamp.hour}:${image.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (image.location.latitude != null &&
                                  image.location.longitude != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Location: ${image.location.latitude!.toStringAsFixed(4)}, ${image.location.longitude!.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFB74D),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CLASSIFICATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    _getCategoryIcon(image.category),
                                    color: _getCategoryColor(image.category),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    image.category,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown[800],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        OutlinedButton(
                          onPressed: () {
                            _shareImageDetails(image);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D5F3F),
                            side: const BorderSide(
                              color: Color(0xFF2D5F3F),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'SHARE',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D5F3F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                            elevation: 0,
                          ),
                          child: const Text(
                            'FINISH',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String selectedCategory = 'Bird';
  bool isRecording = false;
  int recordingTime = 0;
  Timer? recordingTimer;

  final List<String> categories = ['Bird', 'Insect', 'Plant', 'Animal'];

  // Dynamic counts based on actual data
  int get birdsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'bird').length;
    count += allImages.where((i) => i.category.toLowerCase() == 'bird').length;
    return count;
  }

  int get insectsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'insect').length;
    count +=
        allImages.where((i) => i.category.toLowerCase() == 'insect').length;
    return count;
  }

  int get plantsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'plant').length;
    count += allImages.where((i) => i.category.toLowerCase() == 'plant').length;
    return count;
  }

  int get animalsCount {
    int count = 0;
    count +=
        allRecordings.where((r) => r.category.toLowerCase() == 'animal').length;
    count +=
        allImages.where((i) => i.category.toLowerCase() == 'animal').length;
    return count;
  }

  LocationData? currentLocation;
  final Location location = Location();
  bool isLoadingLocation = true;
  StreamSubscription<LocationData>? locationSubscription;

  // Camera variables
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  bool showCameraPreview = false;
  final ImagePicker _imagePicker = ImagePicker();

  // AI variables
  late GenerativeModel _geminiModel;
  bool isProcessingAI = false;
  String? aiResult;

  // Audio recording variables
  FlutterSoundRecorder? _audioRecorder;
  String? recordedAudioPath;
  bool _isRecordingInitialized = false;

  // Storage for all recordings and images (using global storage)
  List<RecordingEntry> get allRecordings => GlobalCaptures.allRecordings;
  List<ImageEntry> get allImages => GlobalCaptures.allImages;

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initializeCamera();
    _initializeAudioRecorder();

    // Listen for global captures changes
    GlobalCaptures.addListener(_onGlobalCapturesChanged);
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    recordingTimer?.cancel();
    cameraController?.dispose();
    if (_audioRecorder != null && _isRecordingInitialized) {
      _audioRecorder!.closeRecorder();
    }
    GlobalCaptures.removeListener(_onGlobalCapturesChanged);
    super.dispose();
  }

  void _onGlobalCapturesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeAI() async {
    // Initialize Gemini AI - you'll need to replace with your actual API key
    // For now, using a placeholder - you should get an API key from Google AI Studio
    const apiKey =
        'AIzaSyAF-gmjoYmEr_ntH7YEmO7RPTgqb3dNNfM'; // Replace this with your actual API key
    _geminiModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        cameraController = CameraController(
          cameras![0], // Use back camera
          ResolutionPreset.high,
          enableAudio: false,
        );
        await cameraController!.initialize();
        setState(() {
          isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  Future<void> _initializeAudioRecorder() async {
    try {
      _audioRecorder = FlutterSoundRecorder();
      await _audioRecorder!.openRecorder();
      setState(() {
        _isRecordingInitialized = true;
      });
    } catch (e) {
      print("Error initializing audio recorder: $e");
      setState(() {
        _isRecordingInitialized = false;
      });
    }
  }

  void _setDefaultLocation() {
    setState(() {
      isLoadingLocation = false;
      currentLocation = LocationData.fromMap({
        'latitude': 12.9716,
        'longitude': 77.5946,
      });
    });
  }

  Future<void> startRecording() async {
    try {
      if (!_isRecordingInitialized) {
        await _initializeAudioRecorder();
      }

      // Request microphone permission
      var micPermission = await ph.Permission.microphone.status;
      if (micPermission.isDenied) {
        micPermission = await ph.Permission.microphone.request();
        if (!micPermission.isGranted) {
          _showCameraError(
              "Microphone permission is required for voice recording.");
          return;
        }
      }

      // Get temporary directory for recording
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'bird_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      recordedAudioPath = '${tempDir.path}/$fileName';

      // Start recording
      await _audioRecorder!.startRecorder(
        toFile: recordedAudioPath,
        codec: Codec.pcm16WAV,
      );

      setState(() {
        isRecording = true;
        recordingTime = 0;
      });

      recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          recordingTime++;
        });
      });
    } catch (e) {
      _showCameraError("Failed to start recording: $e");
    }
  }

  Future<void> stopRecording() async {
    try {
      recordingTimer?.cancel();

      // Stop recording and get the path
      final String? path = await _audioRecorder!.stopRecorder();

      setState(() {
        isRecording = false;
        recordingTime = 0;
      });

      // Process the bird voice with AI
      if (selectedCategory == 'Bird' && path != null) {
        await _processBirdVoice(path);
      }
    } catch (e) {
      _showCameraError("Failed to stop recording: $e");
    }
  }

  // Parse AI response into structured sections
  Map<String, String> _parseAIResponse(String response) {
    final Map<String, String> sections = {
      'description': '',
      'habitat': '',
      'behavior': '',
      'conservation': '',
    };

    final lines = response.split('\n');
    String? currentSection;

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.startsWith('**DESCRIPTION**:')) {
        currentSection = 'description';
        sections['description'] =
            trimmedLine.replaceFirst('**DESCRIPTION**:', '').trim();
      } else if (trimmedLine.startsWith('**HABITAT**:')) {
        currentSection = 'habitat';
        sections['habitat'] =
            trimmedLine.replaceFirst('**HABITAT**:', '').trim();
      } else if (trimmedLine.startsWith('**BEHAVIOR**:')) {
        currentSection = 'behavior';
        sections['behavior'] =
            trimmedLine.replaceFirst('**BEHAVIOR**:', '').trim();
      } else if (trimmedLine.startsWith('**CONSERVATION**:')) {
        currentSection = 'conservation';
        sections['conservation'] =
            trimmedLine.replaceFirst('**CONSERVATION**:', '').trim();
      } else if (currentSection != null && trimmedLine.isNotEmpty) {
        sections[currentSection] =
            (sections[currentSection] ?? '') + ' ' + trimmedLine;
      }
    }

    // Clean up empty sections
    sections.forEach((key, value) {
      if (value.trim().isEmpty) {
        sections[key] = 'Information not available.';
      }
    });

    return sections;
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _processBirdVoice(String audioPath) async {
    setState(() {
      isProcessingAI = true;
      aiResult = null;
    });

    try {
      print("Starting bird voice analysis for: $audioPath");

      // Since Gemini cannot process audio directly, we'll simulate an analysis
      // In a real app, you would:
      // 1. Convert audio to text using speech-to-text (Google Speech-to-Text, Whisper, etc.)
      // 2. Send the transcribed text to Gemini for analysis
      // 3. Or use a specialized bird sound recognition API

      const prompt = '''
      You are an expert ornithologist analyzing a bird sound recording. Since I cannot provide the actual audio file, 
      please provide a realistic analysis of what a typical bird sound recording might contain.
      
      Please provide a structured response in this exact format:

      **DESCRIPTION**: [Detailed description of typical bird vocalizations including pitch variations, rhythm patterns, call types, and species identification clues]

      **HABITAT**: [Typical habitat where such bird sounds would be recorded, including geographic regions and environmental conditions]

      **BEHAVIOR**: [Behavioral context of the vocalizations - mating calls, territory defense, communication, alarm calls, or feeding behaviors]

      **CONSERVATION**: [Conservation status information about common bird species and their vocalization patterns]

      Keep each section informative and realistic (2-3 sentences per section).
      Focus on providing educational content about bird vocalizations.
      ''';

      print("Sending request for simulated bird sound analysis...");
      final response = await _geminiModel.generateContent([
        Content.text(prompt),
      ]);

      final String analysis = response.text ?? "Unable to analyze audio";
      print("AI Response received: ${analysis.length} characters");

      // Parse the structured response
      final sections = _parseAIResponse(analysis);
      print("Parsed sections: ${sections.keys.toList()}");

      setState(() {
        aiResult = analysis;
        isProcessingAI = false;
      });

      // Store the bird recording with current GPS location
      print("Creating recording entry...");
      final recordingEntry = RecordingEntry(
        audioPath: audioPath,
        analysis: analysis,
        description: sections['description'] ?? 'Bird sound recording analysis',
        timestamp: DateTime.now(),
        location: currentLocation != null
            ? LatLng(currentLocation!.latitude!, currentLocation!.longitude!)
            : LatLng(12.9716, 77.5946), // Current GPS location
        category: 'Bird',
      );

      GlobalCaptures.addRecording(recordingEntry);
      print("Recording entry added to GlobalCaptures");

      // Refresh the Collection page if it exists
      if (mounted) {
        setState(() {});
      }

      _showAIResultsDialog();
    } catch (e) {
      print("Error in bird voice analysis: $e");
      setState(() {
        isProcessingAI = false;
        aiResult = "Analysis failed: $e";
      });
      _showCameraError("AI processing failed: $e");
    }
  }

  // Birds use audio recording only - no bird image processing needed

  Future<void> _processInsectImage(String imagePath) async {
    setState(() {
      isProcessingAI = true;
      aiResult = null;
    });

    try {
      const prompt = '''
      You are an expert entomologist and naturalist. Analyze this insect image and provide a structured response in this exact format:

      **DESCRIPTION**: [Detailed physical description of the insect including size, coloration, distinctive features, body segments]
      
      **HABITAT**: [Natural habitat, geographic range, preferred environment, typical locations found]
      
      **BEHAVIOR**: [Typical behaviors, feeding habits, life cycle, social patterns, activity times]
      
      **CONSERVATION**: [Conservation status, threats, population trends, ecological importance]

      Keep each section concise but informative (2-3 sentences per section).
      If this is not clearly an insect, analyze as the most appropriate category.
      ''';

      final imageBytes = await File(imagePath).readAsBytes();
      final response = await _geminiModel.generateContent([
        Content.text(prompt),
        Content.data('image/jpeg', imageBytes),
      ]);

      final String analysis = response.text ?? "Unable to analyze image";

      // Parse the structured response
      final sections = _parseAIResponse(analysis);

      setState(() {
        aiResult = analysis;
        isProcessingAI = false;
      });

      // Store all images including humans with current GPS location
      final imageEntry = ImageEntry(
        imagePath: imagePath,
        analysis: analysis,
        description: sections['description']!,
        habitat: sections['habitat']!,
        behavior: sections['behavior']!,
        conservation: sections['conservation']!,
        timestamp: DateTime.now(),
        location: currentLocation != null
            ? LatLng(currentLocation!.latitude!, currentLocation!.longitude!)
            : LatLng(12.9716, 77.5946), // Current GPS location
        category: analysis.contains("HUMAN DETECTED") ? "Animal" : "Insect",
      );

      GlobalCaptures.addImage(imageEntry);
      print("Insect image entry added to GlobalCaptures");

      // Refresh the Collection page if it exists
      if (mounted) {
        setState(() {});
      }

      _showAIResultsDialog();
    } catch (e) {
      setState(() {
        isProcessingAI = false;
      });
      _showCameraError("AI processing failed: $e");
    }
  }

  Future<void> _processPlantImage(String imagePath) async {
    setState(() {
      isProcessingAI = true;
      aiResult = null;
    });

    try {
      const prompt = '''
      You are an expert botanist and naturalist. Analyze this plant image and provide a structured response in this exact format:

      **DESCRIPTION**: [Detailed physical description of the plant including size, leaf structure, flowers, fruits, distinctive features]
      
      **HABITAT**: [Natural habitat, geographic range, preferred environment, soil conditions, climate requirements]
      
      **BEHAVIOR**: [Growth patterns, seasonal changes, reproduction methods, interactions with other species]
      
      **CONSERVATION**: [Conservation status, threats, population trends, ecological importance, uses]

      Keep each section concise but informative (2-3 sentences per section).
      If this is not clearly a plant, analyze as the most appropriate category.
      ''';

      final imageBytes = await File(imagePath).readAsBytes();
      final response = await _geminiModel.generateContent([
        Content.text(prompt),
        Content.data('image/jpeg', imageBytes),
      ]);

      final String analysis = response.text ?? "Unable to analyze image";

      // Parse the structured response
      final sections = _parseAIResponse(analysis);

      setState(() {
        aiResult = analysis;
        isProcessingAI = false;
      });

      // Store all images including humans with current GPS location
      final imageEntry = ImageEntry(
        imagePath: imagePath,
        analysis: analysis,
        description: sections['description']!,
        habitat: sections['habitat']!,
        behavior: sections['behavior']!,
        conservation: sections['conservation']!,
        timestamp: DateTime.now(),
        location: currentLocation != null
            ? LatLng(currentLocation!.latitude!, currentLocation!.longitude!)
            : LatLng(12.9716, 77.5946), // Current GPS location
        category: analysis.contains("HUMAN DETECTED") ? "Animal" : "Plant",
      );

      GlobalCaptures.addImage(imageEntry);
      print("Plant image entry added to GlobalCaptures");

      // Refresh the Collection page if it exists
      if (mounted) {
        setState(() {});
      }

      _showAIResultsDialog();
    } catch (e) {
      setState(() {
        isProcessingAI = false;
      });
      _showCameraError("AI processing failed: $e");
    }
  }

  Future<void> _processAnimalImage(String imagePath) async {
    setState(() {
      isProcessingAI = true;
      aiResult = null;
    });

    try {
      const prompt = '''
      You are an expert zoologist and naturalist. Analyze this animal image and provide a structured response in this exact format:

      **DESCRIPTION**: [Detailed physical description of the animal including size, coloration, distinctive features, body structure]
      
      **HABITAT**: [Natural habitat, geographic range, preferred environment, territory requirements]
      
      **BEHAVIOR**: [Typical behaviors, feeding habits, social structure, activity patterns, communication]
      
      **CONSERVATION**: [Conservation status, threats, population trends, human interactions, protection efforts]

      Keep each section concise but informative (2-3 sentences per section).
      If this is a human, clearly state "HUMAN DETECTED" and analyze accordingly.
      ''';

      final imageBytes = await File(imagePath).readAsBytes();
      final response = await _geminiModel.generateContent([
        Content.text(prompt),
        Content.data('image/jpeg', imageBytes),
      ]);

      final String analysis = response.text ?? "Unable to analyze image";

      // Parse the structured response
      final sections = _parseAIResponse(analysis);

      setState(() {
        aiResult = analysis;
        isProcessingAI = false;
      });

      // Store all images including humans with current GPS location
      final imageEntry = ImageEntry(
        imagePath: imagePath,
        analysis: analysis,
        description: sections['description']!,
        habitat: sections['habitat']!,
        behavior: sections['behavior']!,
        conservation: sections['conservation']!,
        timestamp: DateTime.now(),
        location: currentLocation != null
            ? LatLng(currentLocation!.latitude!, currentLocation!.longitude!)
            : LatLng(12.9716, 77.5946), // Current GPS location
        category:
            "Animal", // Everything including humans goes to Animal category
      );

      GlobalCaptures.addImage(imageEntry);
      print("Animal image entry added to GlobalCaptures");

      // Refresh the Collection page if it exists
      if (mounted) {
        setState(() {});
      }

      _showAIResultsDialog();
    } catch (e) {
      setState(() {
        isProcessingAI = false;
      });
      _showCameraError("AI processing failed: $e");
    }
  }

  void _showAIResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Analysis Results'),
        content: SingleChildScrollView(
          child: Text(aiResult ?? 'No results available'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCameraPreview() async {
    if (!isCameraInitialized) {
      _showCameraError("Camera not initialized");
      return;
    }

    setState(() {
      showCameraPreview = !showCameraPreview;
    });
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length < 2) {
      _showCameraError("No front camera available");
      return;
    }

    try {
      final newCameraIndex =
          cameras!.indexOf(cameraController!.description) == 0 ? 1 : 0;
      await cameraController!.dispose();

      cameraController = CameraController(
        cameras![newCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await cameraController!.initialize();
      setState(() {});
    } catch (e) {
      print("Error switching camera: $e");
      _showCameraError("Failed to switch camera");
    }
  }

  Future<void> _takePicture() async {
    if (!isCameraInitialized || cameraController == null) {
      _showCameraError("Camera not initialized");
      return;
    }

    try {
      final XFile picture = await cameraController!.takePicture();
      print("Picture taken: ${picture.path}");
      _showSuccessMessage("Photo captured! Analyzing with AI...");

      // Process the image with AI based on category
      switch (selectedCategory) {
        case 'Insect':
          await _processInsectImage(picture.path);
          break;
        case 'Plant':
          await _processPlantImage(picture.path);
          break;
        case 'Animal':
          await _processAnimalImage(picture.path);
          break;
        default:
          _showCameraError("Unknown category for AI processing");
      }
    } catch (e) {
      print("Error taking picture: $e");
      _showCameraError("Failed to take photo");
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        print("Image picked: ${image.path}");
        _showSuccessMessage("Image selected! Analyzing with AI...");

        // Process the image with AI based on category (birds use audio only)
        switch (selectedCategory) {
          case 'Bird':
            _showCameraError(
                "Birds use audio recording, not images. Please use the microphone to record bird sounds.");
            break;
          case 'Insect':
            await _processInsectImage(image.path);
            break;
          case 'Plant':
            await _processPlantImage(image.path);
            break;
          case 'Animal':
            await _processAnimalImage(image.path);
            break;
          default:
            _showCameraError("Unknown category for AI processing");
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      _showCameraError("Failed to select image");
    }
  }

  void _showCameraError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32), // Extra space when on Explore tab

          const SizedBox(height: 20),

          // Category Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: categories.map((category) {
                  bool isSelected = category == selectedCategory;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2D6A4F)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getCategoryIcon(category),
                              size: 20,
                              color:
                                  isSelected ? Colors.white : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Recording Interface
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Category-specific Input Interface
                  if (selectedCategory == 'Bird') ...[
                    // Voice Recording Interface for Birds
                    // Microphone Button
                    GestureDetector(
                      onTap: () {
                        if (isRecording) {
                          stopRecording();
                        } else {
                          startRecording();
                        }
                      },
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: isRecording
                              ? Colors.red
                              : const Color(0xFF2D6A4F),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isRecording
                                      ? Colors.red
                                      : const Color(0xFF2D6A4F))
                                  .withOpacity(0.25),
                              blurRadius: 30,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Timer
                    Text(
                      formatTime(recordingTime),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey[800],
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Text
                    Text(
                      isProcessingAI
                          ? 'AI PROCESSING...'
                          : (isRecording ? 'RECORDING' : 'READY TO RECORD'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color:
                            isProcessingAI ? Colors.orange : Colors.grey[400],
                        letterSpacing: 2,
                      ),
                    ),

                    // AI Processing Indicator
                    if (isProcessingAI) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Analyzing bird song...',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Start Recording Button (only show when not recording)
                    if (!isRecording)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: startRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic, size: 20),
                              SizedBox(width: 8),
                              Text('Start Recording'),
                            ],
                          ),
                        ),
                      ),

                    if (!isRecording) const SizedBox(height: 20),

                    // Instruction Text
                    if (!isRecording)
                      Text(
                        'For best results, record at least 5 seconds of clear\nbirdsong.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ] else ...[
                    // Camera Interface for other categories
                    // Camera Button
                    GestureDetector(
                      onTap: _toggleCameraPreview,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2D6A4F).withOpacity(0.25),
                              blurRadius: 30,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Camera Preview
                    if (showCameraPreview && isCameraInitialized)
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CameraPreview(cameraController!),
                        ),
                      ),

                    // Camera Controls (show when camera is active)
                    if (showCameraPreview && isCameraInitialized) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Close Camera
                          IconButton(
                            onPressed: () {
                              setState(() {
                                showCameraPreview = false;
                              });
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                            iconSize: 40,
                          ),

                          // Take Photo
                          GestureDetector(
                            onTap: _takePicture,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF2D6A4F), width: 4),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF2D6A4F),
                                size: 40,
                              ),
                            ),
                          ),

                          // Switch Camera
                          IconButton(
                            onPressed: _switchCamera,
                            icon: const Icon(Icons.flip_camera_ios,
                                color: Color(0xFF2D6A4F)),
                            iconSize: 40,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Status Text
                    Text(
                      isProcessingAI
                          ? 'AI PROCESSING...'
                          : (isCameraInitialized
                              ? 'CAMERA READY'
                              : 'INITIALIZING...'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color:
                            isProcessingAI ? Colors.orange : Colors.grey[400],
                        letterSpacing: 2,
                      ),
                    ),

                    // AI Processing Indicator
                    if (isProcessingAI) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Analyzing...',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Camera Options
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _takePicture,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D6A4F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 20),
                                SizedBox(width: 8),
                                Text('Take Photo'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _pickImageFromGallery,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: const Color(0xFF2D6A4F),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library, size: 20),
                                SizedBox(width: 8),
                                Text('Gallery'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (!isRecording) const SizedBox(height: 20),

                    // Instruction Text
                    if (!isRecording)
                      Text(
                        'For best results, capture clear image of the ${selectedCategory.toLowerCase()}.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bird':
        return Icons.flutter_dash;
      case 'Insect':
        return Icons.bug_report;
      case 'Plant':
        return Icons.local_florist;
      case 'Animal':
        return Icons.pets;
      default:
        return Icons.explore;
    }
  }
}
