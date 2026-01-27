import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../models/trek.dart';
import '../../services/trek_service.dart';
import '../../services/osm_trek_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/place_submission_service.dart';
import '../../services/google_places_service.dart';
import '../../utils/gpx_parser.dart';
import '../../utils/geo_utils.dart';
import '../../widgets/trek/trek_components.dart';
import 'trek_details_screen.dart';
import 'path_tracking_screen.dart';
import 'draw_path_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'pending_places_screen.dart';

/// Trek List Screen with filtering, search, and pagination
class TrekListScreen extends StatefulWidget {
  const TrekListScreen({super.key});

  @override
  State<TrekListScreen> createState() => _TrekListScreenState();
}

class _TrekListScreenState extends State<TrekListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TrekService _trekService = TrekService();
  final OSMTrekService _osmTrekService = OSMTrekService();
  final GooglePlacesService _googlePlacesService = GooglePlacesService();
  final LocationTrackingService _locationService = LocationTrackingService();
  final PlaceSubmissionService _placeSubmissionService = PlaceSubmissionService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  // State
  List<Trek> _treks = [];
  List<Trek> _nearbyTreks = [];
  List<Trek> _osmTreks = []; // Treks fetched from OpenStreetMap
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingOSM = false;
  bool _hasMoreData = true;
  String? _error;
  TrekCategory? _selectedCategory;
  String _searchQuery = '';
  bool _isAdmin = false;
  bool _isInitialized = false; // Flag to prevent double initialization
  
  // Location state
  Position? _currentPosition;
  bool _isLocationLoading = false;
  String? _locationError;
  // Radius settings per tab (in kilometers)
  static const double _pathsRadiusKm = 50.0; // 50km radius for trekking paths
  static const double _fitnessRadiusKm = 25.0; // 25km for fitness locations
  static const double _poiRadiusKm = 25.0; // 25km for POI
  
  /// Get the search radius based on current tab
  double get _searchRadiusKm {
    switch (_tabController.index) {
      case _tabPaths:
        return _pathsRadiusKm;
      case _tabFitness:
        return _fitnessRadiusKm;
      case _tabPOI:
        return _poiRadiusKm;
      default:
        return _pathsRadiusKm;
    }
  }
  
  // Map view state
  bool _showMapView = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  StreamSubscription<List<Trek>>? _nearbyTreksSubscription;
  
  // Tab indices
  static const int _tabPaths = 0;
  static const int _tabPOI = 1;
  static const int _tabFitness = 2;

  final List<TrekCategory> _pathFilterCategories = [
    TrekCategory.trekkingPoint,
    TrekCategory.natureWalk,
    TrekCategory.cyclePath,
  ];

  final List<TrekCategory> _fitnessFilterCategories = [
    TrekCategory.sportsClub,
    TrekCategory.gym,
    TrekCategory.swimmingPool,
    TrekCategory.yogaCenter,
    TrekCategory.artsCenter,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _initializeLocation();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _placeSubmissionService.isUserAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      // Request location permission when actually needed
      await _locationService.checkAndRequestPermission();
      _currentPosition = await _locationService.getCurrentLocation();
      _locationError = null;

      debugPrint('TrekListScreen: Got location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');

      // Set up streaming subscription for nearby treks
      _setupNearbyTreksStream();

      // Automatically fetch treks from OpenStreetMap based on location (force refresh on init)
      try {
        await _fetchOSMTreks(forceRefresh: true);
      } catch (e) {
        debugPrint('OSM fetch failed: $e');
      }
    } catch (e) {
      debugPrint('TrekListScreen: Location error: $e');
      _locationError = e.toString();
      _currentPosition = null;
    } finally {
      setState(() => _isLocationLoading = false);
      _isInitialized = true;
      _loadTreks();
    }
  }

  /// Fetch treks from OpenStreetMap and Google Places for Trekking Paths tab
  Future<void> _fetchOSMTreks({bool forceRefresh = false}) async {
    if (_currentPosition == null) return;
    setState(() => _isLoadingOSM = true);
    try {
      debugPrint('TrekListScreen: Fetching OSM data for tab  ${_tabController.index}');
      List<Trek> osmTreks = [];
      List<Trek> googleTreks = [];
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      switch (_tabController.index) {
        case _tabFitness:
          // Try Google Places first for fitness locations
          debugPrint('TrekListScreen: Fetching fitness from Google Places...');
          googleTreks = await _googlePlacesService.fetchFitnessPlaces(
            latitude: lat,
            longitude: lng,
            radiusKm: 15,
          );
          debugPrint('TrekListScreen: Google Places returned ${googleTreks.length} fitness locations');
          
          // If Google returns few or no results, fall back to OSM
          if (googleTreks.length < 5) {
            debugPrint('TrekListScreen: Falling back to OSM for additional fitness locations...');
            osmTreks = await _osmTrekService.fetchFitnessLocations(
              latitude: lat,
              longitude: lng,
              radiusKm: 15,
              specificCategory: _selectedCategory,
              forceRefresh: forceRefresh,
            );
            debugPrint('TrekListScreen: OSM returned ${osmTreks.length} fitness locations');
          }
          break;
        case _tabPOI:
          // POI tab shows ONLY user-submitted places (approved by admin)
          // NO Google Places API or OSM data - only Firebase data from user submissions
          debugPrint('TrekListScreen: POI tab uses only user-submitted content (Submit Place, Import GPX, Draw Path)');
          // osmTreks remains empty - Firebase streaming will provide user-submitted POI
          break;
        case _tabPaths:
        default:
          osmTreks = await _osmTrekService.fetchPathLocations(
            latitude: lat,
            longitude: lng,
            radiusKm: 50,
            specificCategory: _selectedCategory,
            forceRefresh: forceRefresh,
          );
          debugPrint('TrekListScreen: Fetched ${osmTreks.length} OSM path locations');
          // Always fetch Google Places for trekking points
          googleTreks = await _googlePlacesService.fetchTrekkingPlaces(
            latitude: lat,
            longitude: lng,
            radiusKm: 50,
          );
          debugPrint('TrekListScreen: Fetched ${googleTreks.length} Google Places trekking points');
          break;
      }
      
      // Merge Google and OSM results, removing duplicates by id
      final allTreks = <String, Trek>{};
      // Add Google results first (priority)
      for (final t in googleTreks) {
        allTreks[t.id] = t;
      }
      // Add OSM results (will not overwrite Google results with same id)
      for (final t in osmTreks) {
        allTreks[t.id] = t;
      }
      final mergedTreks = allTreks.values.toList();
      debugPrint('TrekListScreen: Total ${mergedTreks.length} locations after merge (${googleTreks.length} from Google, ${osmTreks.length} from OSM)');
      
      if (mounted) {
        setState(() {
          _osmTreks = mergedTreks;
          _isLoadingOSM = false;
        });
        _updateMapMarkers();
      }
    } catch (e) {
      debugPrint('Failed to fetch OSM/Google treks: $e');
      if (mounted) {
        setState(() => _isLoadingOSM = false);
      }
    }
  }

  /// Set up real-time streaming for nearby treks
  void _setupNearbyTreksStream() {
    if (_currentPosition == null) return;
    
    _nearbyTreksSubscription?.cancel();
    
    // Determine category for streaming
    TrekCategory? streamCategory;
    if (_tabController.index == _tabPOI) {
      streamCategory = TrekCategory.pointOfInterest;
    } else if (_tabController.index == _tabFitness) {
      // For fitness tab, use specific category if selected, otherwise get all fitness
      streamCategory = _selectedCategory;
    } else {
      // For paths tab, use selected category
      streamCategory = _selectedCategory;
    }
    
    _nearbyTreksSubscription = _trekService.streamTreksNearLocation(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusKm: _searchRadiusKm,
      category: streamCategory,
      limit: 10,
    ).listen((treks) {
      if (mounted) {
        setState(() {
          _nearbyTreks = treks;
          _updateMapMarkers();
        });
      }
    }, onError: (e) {
      // Stream error - fall back to one-time fetch
      debugPrint('Nearby treks stream error: $e');
    });
  }

  /// Update map markers when nearby treks change
  void _updateMapMarkers() {
    if (!_showMapView) return;
    
    final markers = <Marker>{};
    
    // Add user location marker
    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ));
    }
    
    // Combine all treks for markers (nearby + OSM + local)
    final allTreks = <Trek>{..._nearbyTreks, ..._osmTreks, ..._treks};
    
    // Add trek markers
    for (final trek in allTreks) {
      double? lat, lng;
      if (trek.location != null) {
        lat = trek.location!.geopoint.latitude;
        lng = trek.location!.geopoint.longitude;
      } else if (trek.startPoint != null) {
        lat = trek.startPoint!.latitude;
        lng = trek.startPoint!.longitude;
      }
      
      if (lat != null && lng != null) {
        final distance = _calculateDistanceFromUser(trek);
        final isOSMTrek = trek.id.startsWith('osm_');
        markers.add(Marker(
          markerId: MarkerId(trek.id),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(trek.category)),
          infoWindow: InfoWindow(
            title: '${trek.title}${isOSMTrek ? ' 📍' : ''}',
            snippet: distance != null 
                ? '${distance.toStringAsFixed(1)} km away'
                : trek.formattedDistance,
          ),
          onTap: () => _openTrekDetails(trek),
        ));
      }
    }
    
    setState(() => _markers = markers);
  }

  double _getMarkerHue(TrekCategory category) {
    switch (category) {
      case TrekCategory.trekkingPoint:
        return BitmapDescriptor.hueOrange;
      case TrekCategory.natureWalk:
        return BitmapDescriptor.hueGreen;
      case TrekCategory.cyclePath:
        return BitmapDescriptor.hueViolet;
      case TrekCategory.pointOfInterest:
        return BitmapDescriptor.hueRed;
      case TrekCategory.fitnessCenter:
        return BitmapDescriptor.hueYellow;
      case TrekCategory.sportsClub:
        return BitmapDescriptor.hueBlue;
      case TrekCategory.gym:
        return BitmapDescriptor.hueMagenta;
      case TrekCategory.swimmingPool:
        return BitmapDescriptor.hueAzure;
      case TrekCategory.yogaCenter:
        return BitmapDescriptor.hueRose;
      case TrekCategory.artsCenter:
        return BitmapDescriptor.hueOrange;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _nearbyTreksSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !_isInitialized) return;
    setState(() {
      _selectedCategory = null;
      _searchQuery = '';
      _searchController.clear();
      _isLoading = true; // Show loading instead of clearing data
    });
    // Fetch fresh OSM data for the new tab, then reload treks
    _fetchOSMTreks().then((_) {
      if (mounted) _loadTreks();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTreks();
    }
  }

  Future<void> _loadTreks() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _hasMoreData = true;
    });

    try {
      TrekCategory? categoryFilter = _selectedCategory;
      
      // Apply tab-based filtering
      switch (_tabController.index) {
        case _tabPOI:
          categoryFilter = TrekCategory.pointOfInterest;
          break;
        case _tabFitness:
          // If no specific fitness sub-category selected, show all fitness
          if (_selectedCategory == null) {
            categoryFilter = null; // Will filter by isFitnessSubCategory below
          }
          break;
        default:
          // Use selected filter or null for all paths
          break;
      }

      List<Trek> treks;
      List<Trek> nearbyTreks = [];
      
      // If we have location, fetch nearby treks first
      if (_currentPosition != null && _searchQuery.isEmpty) {
        nearbyTreks = await _trekService.getTreksNearLocation(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radiusKm: _searchRadiusKm,
          category: categoryFilter,
          limit: 10,
        );
        
        // Include OSM treks in nearby section (filtered by category if needed)
        List<Trek> filteredOSMTreks = _osmTreks;
        if (_tabController.index == _tabFitness) {
          // For fitness tab, filter by sub-category or show all fitness
          if (_selectedCategory != null) {
            filteredOSMTreks = _osmTreks.where((t) => t.category == _selectedCategory).toList();
          } else {
            filteredOSMTreks = _osmTreks.where((t) => t.category.isFitnessSubCategory).toList();
          }
        } else if (categoryFilter != null) {
          filteredOSMTreks = _osmTreks.where((t) => t.category == categoryFilter).toList();
        }
        
        // Merge nearby treks with OSM treks, removing duplicates
        final nearbyIds = nearbyTreks.map((t) => t.id).toSet();
        for (final osmTrek in filteredOSMTreks) {
          if (!nearbyIds.contains(osmTrek.id)) {
            nearbyTreks.add(osmTrek);
            nearbyIds.add(osmTrek.id);
          }
        }
        
        // Sort combined nearby treks by distance
        if (_currentPosition != null) {
          nearbyTreks.sort((a, b) {
            final distA = _calculateDistanceFromUser(a) ?? double.infinity;
            final distB = _calculateDistanceFromUser(b) ?? double.infinity;
            return distA.compareTo(distB);
          });
        }
        
        // Get all treks (excluding nearby ones to avoid duplicates)
        treks = await _trekService.getTreks(
          category: categoryFilter,
          searchQuery: null,
          limit: 20,
        );
        
        // Remove duplicates
        treks = treks.where((t) => !nearbyIds.contains(t.id)).toList();
      } else if (_searchQuery.isNotEmpty) {
        // Search mode - search in both local and OSM treks
        treks = await _trekService.getTreks(
          category: categoryFilter,
          searchQuery: _searchQuery,
          limit: 20,
        );
        
        // Also search in OSM treks
        final lowerQuery = _searchQuery.toLowerCase();
        final matchingOSMTreks = _osmTreks.where((trek) {
          return trek.title.toLowerCase().contains(lowerQuery) ||
              trek.description.toLowerCase().contains(lowerQuery) ||
              trek.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList();
        
        // Add matching OSM treks that aren't duplicates
        final trekIds = treks.map((t) => t.id).toSet();
        for (final osmTrek in matchingOSMTreks) {
          if (!trekIds.contains(osmTrek.id)) {
            treks.add(osmTrek);
          }
        }
      } else {
        // No location - just get all treks plus OSM treks
        treks = await _trekService.getTreks(
          category: categoryFilter,
          searchQuery: null,
          limit: 20,
        );
        
        // Add OSM treks (filtered by category if needed)
        List<Trek> filteredOSMTreks = _osmTreks;
        if (categoryFilter != null) {
          filteredOSMTreks = _osmTreks.where((t) => t.category == categoryFilter).toList();
        }
        
        final trekIds = treks.map((t) => t.id).toSet();
        for (final osmTrek in filteredOSMTreks) {
          if (!trekIds.contains(osmTrek.id)) {
            treks.add(osmTrek);
          }
        }
      }

      setState(() {
        _nearbyTreks = nearbyTreks;
        _treks = treks;
        _isLoading = false;
        _hasMoreData = treks.length >= 20;
      });
      
      _updateMapMarkers();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTreks() async {
    if (_isLoadingMore || !_hasMoreData || _treks.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      // For pagination, we'd need to pass startAfter document
      // Simplified version just loads more
      final moreTreks = await _trekService.getTreks(
        category: _selectedCategory,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        limit: 20,
      );

      setState(() {
        // In real implementation, append to _treks
        _isLoadingMore = false;
        _hasMoreData = moreTreks.length >= 20;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value) {
        _loadTreks();
      }
    });
  }

  void _onCategorySelected(TrekCategory? category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
      _isLoading = true; // Show loading instead of clearing data
    });
    // Re-fetch OSM data with the new category filter
    if (_tabController.index == _tabPaths || _tabController.index == _tabFitness) {
      _fetchOSMTreks().then((_) {
        if (mounted) _loadTreks();
      });
    } else {
      _loadTreks();
    }
  }

  Future<void> _importGPX() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;
      
      // Check if file has .gpx extension
      if (!filePath.toLowerCase().endsWith('.gpx')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a GPX file')),
          );
        }
        return;
      }

      final file = File(filePath);
      final gpxContent = await file.readAsString();
      final parseResult = GPXParser.parseGPX(gpxContent);

      if (!mounted) return;

      // Show dialog to confirm import
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import GPX'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${parseResult.name}'),
              Text('Distance: ${(parseResult.totalDistance / 1000).toStringAsFixed(1)} km'),
              Text('Elevation gain: ${parseResult.elevationGain.toInt()} m'),
              Text('Points: ${parseResult.points.length}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final trek = parseResult.toTrek(id: '');
        
        // Submit to pendingPlaces for admin approval
        await _placeSubmissionService.submitPlace(
          title: trek.title,
          description: trek.description,
          category: trek.category,
          latitude: trek.startPoint!.latitude,
          longitude: trek.startPoint!.longitude,
          imageUrl: trek.imageUrl,
          routePoints: trek.routePoints,
          distance: trek.distance,
          elevationGain: trek.elevationGain,
          elevationLoss: trek.elevationLoss,
          difficulty: trek.difficulty,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPX imported and submitted for admin approval!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import GPX: $e')),
        );
      }
    }
  }

  void _startRecording() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PathTrackingScreen(),
      ),
    );
  }

  void _drawCustomPath() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DrawPathScreen(),
      ),
    );
  }

  /// Show dialog to submit a new place
  void _showSubmitPlaceDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final websiteController = TextEditingController();
    TrekCategory selectedCategory = TrekCategory.pointOfInterest;
    bool isSubmitting = false;
    bool useCurrentLocation = true;
    double? customLat;
    double? customLng;
    File? selectedImage;
    final imagePicker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: formKey,
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_location_alt, color: AppColors.success),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Submit New Place',
                                    style: GoogleFonts.manrope(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Your submission will be reviewed by admin',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Place Name
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Place Name *',
                            prefixIcon: Icon(Icons.place),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Category
                        DropdownButtonFormField<TrekCategory>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            TrekCategory.pointOfInterest,
                            TrekCategory.trekkingPoint,
                            TrekCategory.natureWalk,
                            TrekCategory.cyclePath,
                            TrekCategory.gym,
                            TrekCategory.swimmingPool,
                            TrekCategory.yogaCenter,
                            TrekCategory.sportsClub,
                            TrekCategory.artsCenter,
                          ].map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.displayName),
                          )).toList(),
                          onChanged: (v) => setSheetState(() => selectedCategory = v!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Photo upload
                        GestureDetector(
                          onTap: () async {
                            try {
                              final pickedFile = await imagePicker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1080,
                                imageQuality: 85,
                              );
                              if (pickedFile != null) {
                                setSheetState(() {
                                  selectedImage = File(pickedFile.path);
                                });
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error picking image: $e')),
                              );
                            }
                          },
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: selectedImage != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(
                                          selectedImage!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          onPressed: () => setSheetState(() => selectedImage = null),
                                          icon: const Icon(Icons.close),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add Photo (Optional)',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                      Text(
                                        'Tap to select from gallery',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Description
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Location option
                        SwitchListTile(
                          title: const Text('Use Current Location'),
                          subtitle: _currentPosition != null
                              ? Text('${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}')
                              : const Text('Location not available'),
                          value: useCurrentLocation,
                          onChanged: _currentPosition != null
                              ? (v) => setSheetState(() => useCurrentLocation = v)
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Address
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address (optional)',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Phone
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone (optional)',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        
                        // Website
                        TextFormField(
                          controller: websiteController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Website (optional)',
                            prefixIcon: Icon(Icons.language),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Submit button
                        FilledButton.icon(
                          onPressed: isSubmitting ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            
                            if (useCurrentLocation && _currentPosition == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Location not available')),
                              );
                              return;
                            }
                            
                            setSheetState(() => isSubmitting = true);
                            
                            try {
                              final lat = useCurrentLocation 
                                  ? _currentPosition!.latitude 
                                  : (customLat ?? _currentPosition!.latitude);
                              final lng = useCurrentLocation 
                                  ? _currentPosition!.longitude 
                                  : (customLng ?? _currentPosition!.longitude);
                              
                              await _placeSubmissionService.submitPlace(
                                title: titleController.text.trim(),
                                description: descriptionController.text.trim(),
                                category: selectedCategory,
                                latitude: lat,
                                longitude: lng,
                                address: addressController.text.trim().isEmpty 
                                    ? null : addressController.text.trim(),
                                phoneNumber: phoneController.text.trim().isEmpty 
                                    ? null : phoneController.text.trim(),
                                website: websiteController.text.trim().isEmpty 
                                    ? null : websiteController.text.trim(),
                                imageUrl: selectedImage?.path, // Store local path for now, admin can upload to storage
                              );
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Place submitted for review!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          icon: isSubmitting 
                              ? const SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label: Text(isSubmitting ? 'Submitting...' : 'Submit for Review'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openTrekDetails(Trek trek) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrekDetailsScreen(trek: trek),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App bar with title
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              title: Text(
                'Trek Explorer',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                // Admin pending places button (only for admins)
                if (_isAdmin)
                  StreamBuilder<int>(
                    stream: _placeSubmissionService.streamPendingCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Badge(
                        label: count > 0 ? Text('$count') : null,
                        isLabelVisible: count > 0,
                        child: IconButton(
                          icon: const Icon(Icons.pending_actions),
                          tooltip: 'Pending Places',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PendingPlacesScreen(),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                // Map/List toggle button
                IconButton(
                  icon: Icon(_showMapView ? Icons.list : Icons.map),
                  tooltip: _showMapView ? 'Show list' : 'Show map',
                  onPressed: () {
                    setState(() {
                      _showMapView = !_showMapView;
                      if (_showMapView) {
                        _updateMapMarkers();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  tooltip: 'Favorites',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'History',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(110),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'Search treks...',
                        leading: const Icon(Icons.search),
                        trailing: _searchQuery.isNotEmpty
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                ),
                              ]
                            : null,
                        onChanged: _onSearchChanged,
                        elevation: WidgetStateProperty.all(0),
                        backgroundColor: WidgetStateProperty.all(
                          isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ),
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Paths'),
                        Tab(text: 'POI'),
                        Tab(text: 'Fitness'),
                      ],
                      labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      indicatorColor: colorScheme.primary,
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips (for Paths and Fitness tabs)
            if ((_tabController.index == _tabPaths || _tabController.index == _tabFitness) && !_showMapView)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: _getCurrentFilterCategories().map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: TrekFilterChip(
                          label: category.displayName,
                          icon: _getCategoryIcon(category),
                          selected: _selectedCategory == category,
                          onTap: () => _onCategorySelected(category),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ];
        },
        body: _showMapView ? _buildMapView() : RefreshIndicator(
          onRefresh: _loadTreks,
          child: _buildBody(),
        ),
      ),
      floatingActionButton: TrekSpeedDialFAB(
        onImportGPX: _importGPX,
        onRecordTrack: _startRecording,
        onDrawPath: _drawCustomPath,
        onSubmitPlace: _showSubmitPlaceDialog,
      ),
    );
  }

  /// Build the map view showing nearby treks
  Widget _buildMapView() {
    if (_currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Location required for map view',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Enable Location'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 12,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            _updateMapMarkers();
          },
        ),
        // Nearby treks count badge
        if (_nearbyTreks.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.near_me, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${_nearbyTreks.length} treks nearby',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _showMapView = false),
                      child: const Text('View List'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        itemCount: 5,
        itemBuilder: (context, index) => const TrekCardShimmer(),
      );
    }

    if (_error != null) {
      return TrekEmptyState(
        title: 'Something went wrong',
        subtitle: _error!,
        icon: Icons.error_outline,
        onRetry: _loadTreks,
      );
    }

    if (_treks.isEmpty && _nearbyTreks.isEmpty && !_isLoadingOSM) {
      String title;
      String subtitle;
      IconData icon;
      
      switch (_tabController.index) {
        case _tabPOI:
          title = 'No community places yet';
          subtitle = _searchQuery.isNotEmpty
              ? 'No results for "$_searchQuery"'
              : 'POI shows community-submitted places. Use "Submit Place", "Import GPX", or "Draw Path" to add locations. All submissions require admin approval.';
          icon = Icons.explore_outlined;
          break;
        case _tabFitness:
          title = 'No fitness centers found';
          subtitle = _searchQuery.isNotEmpty
              ? 'No results for "$_searchQuery"'
              : 'We\'re looking for gyms, yoga centers and sports facilities nearby';
          icon = Icons.fitness_center_outlined;
          break;
        default:
          title = 'No paths found nearby';
          subtitle = _searchQuery.isNotEmpty
              ? 'No results for "$_searchQuery"'
              : 'We\'re discovering trails, cycling paths and nature/jogging routes in your area';
          icon = Icons.route_outlined;
      }
      
      return TrekEmptyState(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onRetry: () {
          _fetchOSMTreks(forceRefresh: true).then((_) {
            if (mounted) _loadTreks();
          });
        },
      );
    }

    // Show loading shimmer while OSM is fetching and we have no data yet
    if (_isLoadingOSM && _treks.isEmpty && _nearbyTreks.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        itemCount: 5,
        itemBuilder: (context, index) => const TrekCardShimmer(),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Location status banner
        if (_locationError != null && _searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: _buildLocationBanner(),
          ),
        
        // Loading OSM treks indicator
        if (_isLoadingOSM && _searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Discovering trails and paths near you...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Near You section (includes auto-fetched OSM treks)
        if (_nearbyTreks.isNotEmpty && _searchQuery.isEmpty) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: 'Discovered Near You',
              subtitle: _currentPosition != null
                  ? 'Trails within ${_searchRadiusKm.toInt()} km • ${_nearbyTreks.where((t) => t.id.startsWith('osm_')).length} from OpenStreetMap'
                  : null,
              icon: Icons.explore_outlined,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final trek = _nearbyTreks[index];
                return TrekCard(
                  trek: trek,
                  onTap: () => _openTrekDetails(trek),
                  onViewDetails: () => _openTrekDetails(trek),
                  distance: _currentPosition != null
                      ? _calculateDistanceFromUser(trek)
                      : null,
                );
              },
              childCount: _nearbyTreks.length,
            ),
          ),
        ] else if (_currentPosition != null && _searchQuery.isEmpty && _treks.isNotEmpty && !_isLoadingOSM) ...[
          // Show message when location is available but no nearby treks
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No trails found within ${_searchRadiusKm.toInt()} km of your location. Showing all available treks.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        
        // All Treks section
        if (_treks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: _nearbyTreks.isNotEmpty ? 'More Treks' : 'Treks',
              subtitle: _searchQuery.isNotEmpty
                  ? 'Results for "$_searchQuery"'
                  : null,
              icon: Icons.terrain,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _treks.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final trek = _treks[index];
                return TrekCard(
                  trek: trek,
                  onTap: () => _openTrekDetails(trek),
                  onViewDetails: () => _openTrekDetails(trek),
                );
              },
              childCount: _treks.length + (_isLoadingMore ? 1 : 0),
            ),
          ),
        ],
        
        // Bottom padding
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildLocationBanner() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _isLocationLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.location_off, color: Colors.orange, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _isLocationLoading
                  ? 'Getting your location...'
                  : 'Enable location to see treks near you',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade800,
              ),
            ),
          ),
          if (!_isLocationLoading)
            TextButton(
              onPressed: _initializeLocation,
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _calculateDistanceFromUser(Trek trek) {
    if (_currentPosition == null) return null;
    
    // Use TrekService's distance calculation which handles both location and startPoint
    final distance = _trekService.getDistanceToTrek(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      trek,
    );
    
    return distance == double.infinity ? null : distance;
  }

  /// Get filter categories based on current tab
  List<TrekCategory> _getCurrentFilterCategories() {
    switch (_tabController.index) {
      case _tabPaths:
        return _pathFilterCategories;
      case _tabFitness:
        return _fitnessFilterCategories;
      default:
        return [];
    }
  }

  IconData _getCategoryIcon(TrekCategory category) {
    switch (category) {
      case TrekCategory.trekkingPoint:
        return Icons.terrain;
      case TrekCategory.natureWalk:
        return Icons.directions_run;
      case TrekCategory.cyclePath:
        return Icons.directions_bike;
      case TrekCategory.pointOfInterest:
        return Icons.place;
      case TrekCategory.fitnessCenter:
        return Icons.fitness_center;
      case TrekCategory.sportsClub:
        return Icons.sports_soccer;
      case TrekCategory.gym:
        return Icons.fitness_center;
      case TrekCategory.swimmingPool:
        return Icons.pool;
      case TrekCategory.yogaCenter:
        return Icons.self_improvement;
      case TrekCategory.artsCenter:
        return Icons.palette;
    }
  }
}
