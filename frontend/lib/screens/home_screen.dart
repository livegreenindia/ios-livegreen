import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';
import '../models/weight_tracking.dart';
import '../screens/camera_page.dart';
import '../screens/history_page.dart';
import '../screens/profile_setup_page.dart';
import '../screens/food_creator_screen.dart';
import '../services/food_api_service.dart';
import '../widgets/weight_update_dialog.dart';
import '../theme/app_theme.dart';

class DailyIntake {
  final DateTime date;
  final Map<String, double> nutrients;
  final double totalCalories;
  final Map<String, double> dailyRequirements;
  final List<String> scannedFoods; // Add scannedFoods field!

  DailyIntake({
    required this.date,
    required this.nutrients,
    required this.totalCalories,
    required this.dailyRequirements,
    required this.scannedFoods, // Add scannedFoods to constructor!
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'nutrients': nutrients,
      'totalCalories': totalCalories,
      'dailyRequirements': dailyRequirements,
      'scannedFoods': scannedFoods, // Add scanned foods to JSON!
    };
  }

  factory DailyIntake.fromJson(Map<String, dynamic> json) {
    return DailyIntake(
      date: DateTime.parse(json['date']),
      nutrients: Map<String, double>.from(json['nutrients']),
      totalCalories: json['totalCalories'].toDouble(),
      dailyRequirements: Map<String, double>.from(json['dailyRequirements']),
      scannedFoods: json['scannedFoods'] != null
          ? List<String>.from(json['scannedFoods'])
          : [], // Load scanned foods from JSON!
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final UserProfile profile;
  final Function(String, String)? onFoodAdded;
  final Function(UserProfile)? onProfileUpdated;
  final VoidCallback? onClearHistory;

  const HomeScreen(
      {Key? key,
      required this.cameras,
      required this.profile,
      this.onFoodAdded,
      this.onProfileUpdated,
      this.onClearHistory})
      : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final String _apiKey = 'AIzaSyCvhuO5p1bTqNiUxmU5il8gg45GlzDl-Ks';
  List<String> _scannedFoods = [];
  Map<String, double> _totalNutrients = {
    'calories': 0,
    'protein': 0,
    'carbohydrates': 0,
    'fat': 0,
    'fiber': 0,
    // Fiber breakdown
    'totalFiber': 0,
    'solubleFiber': 0,
    'insolubleFiber': 0,
    'prebioticFiber': 0,
    'sodium': 0,
    'addedSugar': 0,
    'cholesterol': 0,
    'refinedCarbs': 0,
    // Detailed fat breakdown
    'monounsaturatedFat': 0,
    'omega3': 0,
    'omega6': 0,
    'saturatedFat': 0,
    'transFat': 0,
    // Core Vitamins
    'vitaminA': 0,
    'vitaminC': 0,
    'vitaminD': 0,
    'vitaminB12': 0,
    // Full Vitamins Summary
    'vitaminE': 0,
    'vitaminK': 0,
    'vitaminB1': 0,
    'vitaminB2': 0,
    'vitaminB3': 0,
    'vitaminB5': 0,
    'vitaminB6': 0,
    'vitaminB7': 0,
    'vitaminB9': 0,
    'folate': 0,
    // Minerals Summary
    'calcium': 0,
    'iron': 0,
    'magnesium': 0,
    'potassium': 0,
    'zinc': 0,
    'phosphorus': 0,
    'copper': 0,
    'manganese': 0,
    'selenium': 0,
  };

  // Food creator form controllers
  final _foodNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showFoodForm = false;
  bool _isLoading = false;
  List<FoodItem> _searchResults = [];
  bool _isSearching = false;

  // Scroll controller for auto-scrolling to food form
  final _scrollController = ScrollController();
  final _foodFormKey = GlobalKey();

  // Weight update block visibility management
  bool _showWeightUpdateBlock = false;
  static const String _profileCreationTimeKey = 'profile_creation_time';
  static const String _lastWeightUpdateTimeKey = 'last_weight_update_time';
  static const String _weightBlockVisibleKey = 'weight_update_block_visible';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDailyIntake();
    // _saveDailyIntake(); // DISABLED - MainTabScreen handles saving to prevent duplicates
    // Calculate AI health limits when app starts
    if (!_isCalculatingLimits) {
      _calculateHealthLimitsWithAI();
    }
    // Save profile creation time and check state
    _saveProfileCreationTime();
    _checkPersistentTimerState();
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Save current timer state when app is paused
      _saveCurrentTimerState();
    }
  }

  Future<void> _saveCurrentTimerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_showWeightUpdateBlock) {
        // Block is visible, save that state
        await _saveTimerState(true);
      } else {
        // Block is not visible, save that state
        await _saveTimerState(false);
      }
    } catch (e) {
      print('Error saving current timer state: $e');
    }
  }

  Future<void> _checkPersistentTimerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileCreationTime = prefs.getInt(_profileCreationTimeKey);
      final lastWeightUpdateTime = prefs.getInt(_lastWeightUpdateTimeKey);
      final blockVisible = prefs.getBool(_weightBlockVisibleKey) ?? false;

      if (profileCreationTime != null) {
        final creationDate =
            DateTime.fromMillisecondsSinceEpoch(profileCreationTime);
        final currentDate = DateTime.now();
        final daysSinceCreation = currentDate.difference(creationDate).inDays;

        // Check if 15 days have passed since profile creation
        if (daysSinceCreation >= 15) {
          if (lastWeightUpdateTime != null) {
            final lastUpdateDate =
                DateTime.fromMillisecondsSinceEpoch(lastWeightUpdateTime);
            final daysSinceLastUpdate =
                currentDate.difference(lastUpdateDate).inDays;

            // Show block if it's been 15 days since last weight update
            if (daysSinceLastUpdate >= 15) {
              if (mounted) {
                setState(() {
                  _showWeightUpdateBlock = true;
                });
              }
            }
          } else {
            // No weight update recorded, show block
            if (mounted) {
              setState(() {
                _showWeightUpdateBlock = true;
              });
            }
          }
        }
      } else if (blockVisible) {
        // Show block if it was visible when app closed (fallback)
        if (mounted) {
          setState(() {
            _showWeightUpdateBlock = true;
          });
        }
      }
    } catch (e) {
      print('Error checking profile state: $e');
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('=== DEBUG: didUpdateWidget called ===');
    print('=== DEBUG: Old profile weight: ${oldWidget.profile.weight} ===');
    print('=== DEBUG: New profile weight: ${widget.profile.weight} ===');

    // Update daily requirements when profile changes (check individual attributes)
    if (widget.profile.weight != oldWidget.profile.weight ||
        widget.profile.height != oldWidget.profile.height ||
        widget.profile.age != oldWidget.profile.age ||
        widget.profile.gender != oldWidget.profile.gender ||
        widget.profile.activityLevel != oldWidget.profile.activityLevel ||
        widget.profile.goal != oldWidget.profile.goal ||
        widget.profile.state != oldWidget.profile.state ||
        !_listsEqual(widget.profile.healthConditions,
            oldWidget.profile.healthConditions) ||
        !_mapsEqual(
            widget.profile.healthGoals, oldWidget.profile.healthGoals)) {
      print('=== DEBUG: Profile changed, forcing UI refresh ===');
      setState(() {
        // Using widget.profile.dailyNutrientRequirements directly for fresh values
        print('=== DEBUG: Forcing refresh of all UI components ===');
        // Recalculate health limits when profile changes
        if (!_isCalculatingLimits) {
          _calculateHealthLimitsWithAI();
        }
      });
    } else {
      print('=== DEBUG: No profile changes detected ===');
    }
  }

  // Helper method to compare lists
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Helper method to compare maps
  bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  Future<void> _loadDailyIntake() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    final dailyIntakeJson = prefs.getString('dailyIntake_$todayKey');
    if (dailyIntakeJson != null) {
      final intake = DailyIntake.fromJson(
          Map<String, dynamic>.from(json.decode(dailyIntakeJson)));
      setState(() {
        _totalNutrients = Map.from(intake.nutrients);
        _scannedFoods = List.from(intake.scannedFoods); // Load scanned foods!
      });
    } else {
      // Check if we have old data from previous day to clear
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      final yesterdayData = prefs.getString('dailyIntake_$yesterdayKey');

      if (yesterdayData != null) {
        // New day started, clear previous day's data
        setState(() {
          _scannedFoods.clear();
          _totalNutrients = {
            'calories': 0,
            'protein': 0,
            'carbohydrates': 0,
            'fat': 0,
            'fiber': 0,
          };
        });
      }
    }
  }

  Future<void> _saveDailyIntake() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    final dailyIntake = DailyIntake(
      date: today,
      nutrients: Map.from(_totalNutrients),
      totalCalories: _totalNutrients['calories'] ?? 0,
      dailyRequirements: widget.profile.dailyNutrientRequirements,
      scannedFoods: List.from(_scannedFoods), // Add scannedFoods parameter!
    );

    await prefs.setString(
        'dailyIntake_$todayKey', json.encode(dailyIntake.toJson()));

    // Also add to history list
    final historyJson = prefs.getStringList('dailyIntakeHistory') ?? [];
    historyJson.add(json.encode(dailyIntake.toJson()));
    await prefs.setStringList('dailyIntakeHistory', historyJson);
  }

  void _hideWeightUpdateBlock() {
    setState(() {
      _showWeightUpdateBlock = false;
    });
    // Save weight update time
    _saveTimerState(false);
  }

  Future<void> _saveTimerState(bool blockVisible) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (blockVisible) {
        // Save that block should be visible
        await prefs.setBool(_weightBlockVisibleKey, true);
      } else {
        // Save weight update time when block is hidden
        await prefs.setInt(
            _lastWeightUpdateTimeKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool(_weightBlockVisibleKey, false);
      }
    } catch (e) {
      print('Error saving timer state: $e');
    }
  }

  Future<void> _clearTimerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_weightBlockVisibleKey);
    } catch (e) {
      print('Error clearing timer state: $e');
    }
  }

  Future<void> _saveProfileCreationTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_profileCreationTimeKey)) {
        await prefs.setInt(
            _profileCreationTimeKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      print('Error saving profile creation time: $e');
    }
  }

  bool _isLikelyFood(String searchTerm) {
    // Lists of common food and non-food keywords
    final List<String> foodKeywords = [
      'apple',
      'banana',
      'orange',
      'grape',
      'strawberry',
      'blueberry',
      'watermelon',
      'chicken',
      'beef',
      'pork',
      'fish',
      'salmon',
      'tuna',
      'shrimp',
      'rice',
      'pasta',
      'bread',
      'potato',
      'carrot',
      'broccoli',
      'spinach',
      'milk',
      'cheese',
      'yogurt',
      'egg',
      'butter',
      'oil',
      'sugar',
      'salt',
      'pepper',
      'flour',
      'water',
      'coffee',
      'tea',
      'tomato',
      'onion',
      'garlic',
      'lettuce',
      'cucumber',
      'pepper',
      'beans',
      'lentils',
      'nuts',
      'almond',
      'walnut',
      'peanut',
      'honey',
      'jam',
      'sauce',
      'soup',
      'salad',
      'sandwich',
      'pizza',
      'burger',
      'cake',
      'cookie',
      'chocolate',
      'ice cream',
      'raw',
      'fresh',
      'cooked',
      'grilled',
      'baked',
      'fried',
      'roasted'
    ];

    final List<String> nonFoodKeywords = [
      'phone',
      'computer',
      'laptop',
      'tablet',
      'car',
      'bike',
      'book',
      'pen',
      'paper',
      'desk',
      'chair',
      'door',
      'window',
      'wall',
      'shoe',
      'shirt',
      'pants',
      'hat',
      'bag',
      'wallet',
      'key',
      'tv',
      'radio',
      'speaker',
      'headphone',
      'camera',
      'battery',
      'soap',
      'shampoo',
      'toothpaste',
      'towel',
      'tissue',
      'plastic',
      'metal',
      'wood',
      'glass',
      'stone',
      'concrete',
      'brick',
      'game',
      'toy',
      'ball',
      'doll',
      'puzzle',
      'card',
      'board',
      'medicine',
      'pill',
      'drug',
      'vitamin',
      'supplement',
      'chemical',
      'acid',
      'poison',
      'toxic',
      'dangerous',
      'fuck',
      'shit',
      'ass',
      'bitch',
      'damn',
      'hell'
    ];

    // Check for non-food keywords first (higher priority)
    for (final keyword in nonFoodKeywords) {
      if (searchTerm.contains(keyword)) {
        return false;
      }
    }

    // Check for food keywords
    for (final keyword in foodKeywords) {
      if (searchTerm.contains(keyword)) {
        return true;
      }
    }

    // Additional heuristics
    // Very short words (1-2 characters) are unlikely to be complete food names
    if (searchTerm.length <= 2) {
      return false;
    }

    // Words with numbers are unlikely to be food (unless it's a quantity)
    if (RegExp(r'\d').hasMatch(searchTerm) &&
        !RegExp(r'\d\s*(g|kg|oz|lb|cup|tsp|tbsp)').hasMatch(searchTerm)) {
      return false;
    }

    // Common food patterns
    if (RegExp(r'(raw|fresh|cooked|grilled|baked|fried|roasted)\s+\w+')
        .hasMatch(searchTerm)) {
      return true;
    }

    // If no clear indicators, assume it might be food (let the API decide)
    return true;
  }

  Future<Map<String, dynamic>?> _fetchFoodNutrients(
      String foodName, double quantity) async {
    try {
      // First validate if it's actually food using Gemini
      final isFood = await _validateFoodWithGemini(foodName);
      if (!isFood) {
        print('Not a food item (Gemini validation): $foodName');
        return null;
      }

      // Then get nutrition information
      final nutritionData = await _getNutritionFromGemini(foodName, quantity);

      if (nutritionData == null) {
        print('No nutrition data found from Gemini: $foodName');
        return null;
      }

      print('Gemini provided nutrition for $foodName: $nutritionData');

      return {
        'productName': foodName,
        'nutrients': nutritionData,
        'found': true,
      };
    } catch (e) {
      print('Error getting nutrition from Gemini: $e');
      return null;
    }
  }

  Future<Map<String, double>?> _getNutritionFromGemini(
      String foodName, double quantity) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

      final prompt =
          '''Provide nutrition information for "$foodName" ($quantity grams).

Respond with ONLY a JSON object containing these exact keys:
{
  "calories": number,
  "protein": number,
  "carbohydrates": number,
  "fat": number,
  "fiber": number,
  "sodium": number,
  "addedSugar": number,
  "transFat": number,
  "saturatedFat": number,
  "refinedCarbs": number,
  "cholesterol": number,
  
  // Fiber Breakdown
  "totalFiber": number,
  "solubleFiber": number,
  "insolubleFiber": number,
  "prebioticFiber": number,
  
  // Fat Breakdown
  "monounsaturatedFat": number,
  "omega3": number,
  "omega6": number,
  
  // Vitamins (Complete Set)
  "vitaminA": number,
  "vitaminC": number,
  "vitaminD": number,
  "vitaminE": number,
  "vitaminK": number,
  "vitaminB1": number,
  "vitaminB2": number,
  "vitaminB3": number,
  "vitaminB5": number,
  "vitaminB6": number,
  "vitaminB7": number,
  "vitaminB9": number,
  "vitaminB12": number,
  "folate": number,
  
  // Minerals (Complete Set)
  "calcium": number,
  "iron": number,
  "potassium": number,
  "magnesium": number,
  "zinc": number,
  "phosphorus": number,
  "copper": number,
  "manganese": number,
  "selenium": number
}

Values should be per $quantity grams. Use 0 if unknown.

Example for 100g apple:
{
  "calories": 52,
  "protein": 0.3,
  "carbohydrates": 14,
  "fat": 0.2,
  "fiber": 2.4,
  "totalFiber": 2.4,
  "solubleFiber": 1.0,
  "insolubleFiber": 1.4,
  "prebioticFiber": 0.2,
  "sodium": 1,
  "addedSugar": 10,
  "transFat": 0,
  "saturatedFat": 0.03,
  "refinedCarbs": 5,
  "cholesterol": 0,
  "monounsaturatedFat": 0.01,
  "omega3": 0.01,
  "omega6": 0.04,
  "vitaminA": 54,
  "vitaminC": 4.6,
  "vitaminD": 0,
  "vitaminE": 0.18,
  "vitaminK": 2.2,
  "vitaminB1": 0.017,
  "vitaminB2": 0.026,
  "vitaminB3": 0.091,
  "vitaminB5": 0.061,
  "vitaminB6": 0.041,
  "vitaminB7": 0.001,
  "vitaminB9": 3,
  "vitaminB12": 0,
  "folate": 3,
  "calcium": 6,
  "iron": 0.12,
  "potassium": 107,
  "magnesium": 5,
  "zinc": 0.04,
  "phosphorus": 11,
  "copper": 0.019,
  "manganese": 0.035,
  "selenium": 0
}

Your response:''';

      final response = await model.generateContent([Content.text(prompt)]);
      final result = response.text?.trim();

      if (result == null) return null;

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(result);
      if (jsonMatch == null) return null;

      final jsonString = jsonMatch.group(0)!;
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Convert all values to double
      final Map<String, double> nutritionData = {};
      for (final key in jsonData.keys) {
        final value = jsonData[key];
        if (value is num) {
          nutritionData[key] = value.toDouble();
        } else if (value is String) {
          nutritionData[key] = double.tryParse(value) ?? 0.0;
        } else {
          nutritionData[key] = 0.0;
        }
      }

      // Ensure all required keys exist
      final requiredKeys = [
        // Macronutrients
        'calories', 'protein', 'carbohydrates', 'fat', 'fiber', 'sodium',

        // Health Limits
        'addedSugar', 'transFat', 'saturatedFat', 'refinedCarbs', 'cholesterol',

        // Fiber Breakdown
        'totalFiber', 'solubleFiber', 'insolubleFiber', 'prebioticFiber',

        // Fat Breakdown
        'monounsaturatedFat', 'omega3', 'omega6',

        // Vitamins
        'vitaminA', 'vitaminC', 'vitaminD', 'vitaminE', 'vitaminK',
        'vitaminB1', 'vitaminB2', 'vitaminB3', 'vitaminB5', 'vitaminB6',
        'vitaminB7', 'vitaminB9', 'vitaminB12', 'folate',

        // Minerals
        'calcium', 'iron', 'potassium', 'magnesium', 'zinc',
        'phosphorus', 'copper', 'manganese', 'selenium'
      ];

      for (final key in requiredKeys) {
        nutritionData.putIfAbsent(key, () => 0.0);
      }

      return nutritionData;
    } catch (e) {
      print('Error parsing Gemini nutrition response: $e');
      // If Gemini fails (quota exceeded), fall back to local database
      print('Falling back to local nutrition database...');
      return _getLocalNutritionData(foodName, quantity);
    }
  }

  Map<String, double>? _getLocalNutritionData(
      String foodName, double quantity) {
    final searchTerm = foodName.toLowerCase().trim();

    // Local nutrition database (per 100g)
    final Map<String, Map<String, double>> localDatabase = {
      // Fruits
      'apple': {
        'calories': 52, 'protein': 0.3, 'carbohydrates': 14, 'fat': 0.2,
        'fiber': 2.4, 'sodium': 1, 'addedSugar': 10, 'cholesterol': 0,
        'monounsaturatedFat': 0.01, 'omega3': 0.01, 'omega6': 0.04,
        'saturatedFat': 0.03, 'transFat': 0,
        // Fiber breakdown
        'totalFiber': 2.4, 'solubleFiber': 1.0, 'insolubleFiber': 1.4,
        'prebioticFiber': 0.2,
        // Vitamins
        'vitaminA': 54, 'vitaminC': 4.6, 'vitaminD': 0, 'vitaminE': 0.18,
        'vitaminK': 2.2,
        'vitaminB1': 0.017, 'vitaminB2': 0.026, 'vitaminB3': 0.091,
        'vitaminB5': 0.061,
        'vitaminB6': 0.041, 'vitaminB7': 0.001, 'vitaminB9': 3, 'vitaminB12': 0,
        'folate': 3,
        // Minerals
        'calcium': 6, 'iron': 0.12, 'potassium': 107, 'magnesium': 5,
        'zinc': 0.04,
        'phosphorus': 11, 'copper': 0.019, 'manganese': 0.035, 'selenium': 0,
        // Health limits
        'refinedCarbs': 5
      },
      'banana': {
        'calories': 89, 'protein': 1.1, 'carbohydrates': 23, 'fat': 0.3,
        'fiber': 2.6, 'sodium': 1, 'addedSugar': 12, 'cholesterol': 0,
        'monounsaturatedFat': 0.04, 'omega3': 0.03, 'omega6': 0.05,
        'saturatedFat': 0.11, 'transFat': 0,
        // Fiber breakdown
        'totalFiber': 2.6, 'solubleFiber': 1.0, 'insolubleFiber': 1.6,
        'prebioticFiber': 0.3,
        // Vitamins
        'vitaminA': 64, 'vitaminC': 8.7, 'vitaminD': 0, 'vitaminE': 0.27,
        'vitaminK': 0.5,
        'vitaminB1': 0.031, 'vitaminB2': 0.073, 'vitaminB3': 0.665,
        'vitaminB5': 0.334,
        'vitaminB6': 0.367, 'vitaminB7': 0.018, 'vitaminB9': 20,
        'vitaminB12': 0, 'folate': 20,
        // Minerals
        'calcium': 5, 'iron': 0.26, 'potassium': 358, 'magnesium': 27,
        'zinc': 0.15,
        'phosphorus': 22, 'copper': 0.078, 'manganese': 0.27, 'selenium': 1.2,
        // Health limits
        'refinedCarbs': 8
      },
      'orange': {
        'calories': 47,
        'protein': 0.9,
        'carbohydrates': 12,
        'fat': 0.1,
        'fiber': 2.4,
        'sodium': 0,
        'addedSugar': 9,
        'cholesterol': 0,
        'monounsaturatedFat': 0.02,
        'omega3': 0.01,
        'omega6': 0.02,
        'saturatedFat': 0.02,
        'transFat': 0
      },

      // Vegetables
      'carrot': {
        'calories': 41,
        'protein': 0.9,
        'carbohydrates': 10,
        'fat': 0.2,
        'fiber': 2.8,
        'sodium': 69,
        'addedSugar': 5,
        'cholesterol': 0,
        'monounsaturatedFat': 0.01,
        'omega3': 0.01,
        'omega6': 0.03,
        'saturatedFat': 0.04,
        'transFat': 0
      },
      'broccoli': {
        'calories': 34,
        'protein': 2.8,
        'carbohydrates': 7,
        'fat': 0.4,
        'fiber': 2.6,
        'sodium': 33,
        'addedSugar': 1.5,
        'cholesterol': 0,
        'monounsaturatedFat': 0.01,
        'omega3': 0.02,
        'omega6': 0.02,
        'saturatedFat': 0.05,
        'transFat': 0
      },
      'tomato': {
        'calories': 18,
        'protein': 0.9,
        'carbohydrates': 3.9,
        'fat': 0.2,
        'fiber': 1.2,
        'sodium': 5,
        'addedSugar': 2.6,
        'cholesterol': 0,
        'monounsaturatedFat': 0.03,
        'omega3': 0.01,
        'omega6': 0.01,
        'saturatedFat': 0.03,
        'transFat': 0
      },

      // Proteins
      'chicken': {
        'calories': 165, 'protein': 31, 'carbohydrates': 0, 'fat': 3.6,
        'fiber': 0, 'sodium': 74, 'addedSugar': 0, 'cholesterol': 85,
        'monounsaturatedFat': 1.1, 'omega3': 0.1, 'omega6': 0.8,
        'saturatedFat': 1.0, 'transFat': 0,
        // Fiber breakdown
        'totalFiber': 0, 'solubleFiber': 0, 'insolubleFiber': 0,
        'prebioticFiber': 0,
        // Vitamins
        'vitaminA': 21, 'vitaminC': 0, 'vitaminD': 0, 'vitaminE': 0.27,
        'vitaminK': 0.3,
        'vitaminB1': 0.055, 'vitaminB2': 0.114, 'vitaminB3': 7.9,
        'vitaminB5': 1.0,
        'vitaminB6': 0.6, 'vitaminB7': 0.009, 'vitaminB9': 5, 'vitaminB12': 0.3,
        'folate': 5,
        // Minerals
        'calcium': 15, 'iron': 1.0, 'potassium': 223, 'magnesium': 23,
        'zinc': 1.0,
        'phosphorus': 196, 'copper': 0.04, 'manganese': 0.018, 'selenium': 20.6,
        // Health limits
        'refinedCarbs': 0
      },
      'egg': {
        'calories': 155,
        'protein': 13,
        'carbohydrates': 1.1,
        'fat': 11,
        'fiber': 0,
        'sodium': 124,
        'addedSugar': 1.1,
        'cholesterol': 373,
        'monounsaturatedFat': 3.7,
        'omega3': 0.1,
        'omega6': 1.2,
        'saturatedFat': 3.3,
        'transFat': 0
      },
      'fish': {
        'calories': 208,
        'protein': 20,
        'carbohydrates': 0,
        'fat': 13,
        'fiber': 0,
        'sodium': 60,
        'addedSugar': 0,
        'cholesterol': 80,
        'monounsaturatedFat': 4.5,
        'omega3': 2.0,
        'omega6': 1.5,
        'saturatedFat': 3.0,
        'transFat': 0
      },

      // Grains
      'rice': {
        'calories': 130,
        'protein': 2.7,
        'carbohydrates': 28,
        'fat': 0.3,
        'fiber': 0.4,
        'sodium': 1,
        'addedSugar': 0.1,
        'cholesterol': 0,
        'monounsaturatedFat': 0.09,
        'omega3': 0.02,
        'omega6': 0.1,
        'saturatedFat': 0.09,
        'transFat': 0
      },
      'bread': {
        'calories': 265,
        'protein': 9,
        'carbohydrates': 49,
        'fat': 3.2,
        'fiber': 2.7,
        'sodium': 491,
        'addedSugar': 5,
        'cholesterol': 0,
        'monounsaturatedFat': 0.7,
        'omega3': 0.1,
        'omega6': 0.8,
        'saturatedFat': 0.8,
        'transFat': 0
      },
      'pasta': {
        'calories': 131,
        'protein': 5,
        'carbohydrates': 25,
        'fat': 1.1,
        'fiber': 1.8,
        'sodium': 6,
        'addedSugar': 0.6,
        'cholesterol': 33,
        'monounsaturatedFat': 0.2,
        'omega3': 0.02,
        'omega6': 0.2,
        'saturatedFat': 0.2,
        'transFat': 0
      },

      // Dairy
      'milk': {
        'calories': 42,
        'protein': 3.4,
        'carbohydrates': 5,
        'fat': 1,
        'fiber': 0,
        'sodium': 44,
        'addedSugar': 5,
        'cholesterol': 5,
        'monounsaturatedFat': 0.3,
        'omega3': 0.01,
        'omega6': 0.04,
        'saturatedFat': 0.6,
        'transFat': 0
      },
      'cheese': {
        'calories': 402,
        'protein': 25,
        'carbohydrates': 1.3,
        'fat': 33,
        'fiber': 0,
        'sodium': 621,
        'addedSugar': 0.5,
        'cholesterol': 95,
        'monounsaturatedFat': 10,
        'omega3': 0.3,
        'omega6': 0.8,
        'saturatedFat': 21,
        'transFat': 1.0
      },
      'yogurt': {
        'calories': 59,
        'protein': 10,
        'carbohydrates': 3.6,
        'fat': 0.4,
        'fiber': 0,
        'sodium': 36,
        'addedSugar': 3.6,
        'cholesterol': 5,
        'monounsaturatedFat': 0.1,
        'omega3': 0.01,
        'omega6': 0.02,
        'saturatedFat': 0.2,
        'transFat': 0
      }
    };

    // Find matching food in database
    Map<String, double>? nutritionData;

    // Exact match first
    if (localDatabase.containsKey(searchTerm)) {
      nutritionData = localDatabase[searchTerm];
    } else {
      // Partial match
      for (final key in localDatabase.keys) {
        if (searchTerm.contains(key) || key.contains(searchTerm)) {
          nutritionData = localDatabase[key];
          break;
        }
      }
    }

    if (nutritionData == null) {
      print('No local data found for: $foodName');
      return null;
    }

    // Adjust for quantity (database is per 100g)
    final multiplier = quantity / 100.0;
    final adjustedData = <String, double>{};

    for (final key in nutritionData.keys) {
      adjustedData[key] = nutritionData[key]! * multiplier;
    }

    print('Using local nutrition data for $foodName: $adjustedData');
    return adjustedData;
  }

  Future<bool> _validateFoodWithGemini(String foodName) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

      final prompt =
          '''Is "$foodName" a food item that can be eaten for nutrition? 

Respond with ONLY:
- "YES" if it's food (fruits, vegetables, meat, grains, dairy, etc.)
- "NO" if it's not food (electronics, furniture, chemicals, etc.)

Examples:
- "apple" → YES
- "chicken" → YES  
- "phone" → NO
- "car" → NO
- "shampoo" → NO

Your response:''';

      final response = await model.generateContent([Content.text(prompt)]);
      final result = response.text?.trim().toUpperCase();

      print('Gemini validation for "$foodName": $result');

      return result == 'YES';
    } catch (e) {
      print('Error validating food with Gemini: $e');
      // If Gemini fails, fall back to local validation
      return _isLikelyFood(foodName.toLowerCase().trim());
    }
  }

  bool _isConfirmedFoodByAPI(Map<String, dynamic> product) {
    final categories = product['categories_tags'] as List? ?? [];
    final ingredients = product['ingredients_text'] as String? ?? '';
    final productName =
        (product['product_name'] as String? ?? '').toLowerCase();

    // Food categories that indicate it's actually food
    final foodCategories = [
      'en:fruits',
      'en:vegetables',
      'en:meats',
      'en:fish',
      'en:dairy',
      'en:grains',
      'en:legumes',
      'en:nuts',
      'en:beverages',
      'en:condiments',
      'en:snacks',
      'en:sweets',
      'en:baked-goods',
      'en:breakfasts',
      'en:plant-based-foods',
      'en:meals',
      'en:soups',
      'en:sauces'
    ];

    // Non-food categories to exclude
    final nonFoodCategories = [
      'en:beauty',
      'en:cosmetics',
      'en:household',
      'en:cleaning',
      'en:pet-foods',
      'en:medicines',
      'en:supplements',
      'en:vitamins'
    ];

    // Check for non-food categories first
    for (final category in nonFoodCategories) {
      if (categories.contains(category)) return false;
    }

    // Check for food categories
    for (final category in foodCategories) {
      if (categories.contains(category)) return true;
    }

    // Check ingredients text for food indicators
    if (ingredients.isNotEmpty) {
      final foodIngredients = [
        'water',
        'sugar',
        'salt',
        'flour',
        'milk',
        'egg',
        'butter',
        'oil',
        'vinegar',
        'spice',
        'herb',
        'fruit',
        'vegetable'
      ];
      for (final ingredient in foodIngredients) {
        if (ingredients.toLowerCase().contains(ingredient)) return true;
      }
    }

    // Check product name for food indicators
    final foodIndicators = [
      'milk',
      'bread',
      'cheese',
      'chicken',
      'beef',
      'pork',
      'fish',
      'apple',
      'banana',
      'orange',
      'rice',
      'pasta',
      'pizza',
      'burger'
    ];
    for (final indicator in foodIndicators) {
      if (productName.contains(indicator)) return true;
    }

    // If no clear indicators, use nutrient data as final check
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    if (nutriments.isNotEmpty &&
        (nutriments['energy-kcal_100g'] != null ||
            nutriments['proteins_100g'] != null)) {
      return true; // Has nutritional data, likely food
    }

    return false; // Default to not food if no indicators
  }

  String _formatTargetDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  double? _parseNutrient(dynamic value) {
    if (value == null) return null;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _calculateTargetValues() {
    final currentWeight = widget.profile.weight;
    final height = widget.profile.height;
    final age = widget.profile.age;
    final gender = widget.profile.gender;

    print('=== DEBUG: _calculateTargetValues called ===');
    print('=== DEBUG: Profile weight: $currentWeight ===');
    print('=== DEBUG: Profile height: $height ===');
    print('=== DEBUG: Profile age: $age ===');
    print('=== DEBUG: Profile gender: $gender ===');

    // Calculate current BMI
    final heightInMeters = height / 100;
    final currentBMI = currentWeight / (heightInMeters * heightInMeters);

    // Calculate target weight for healthy BMI (18.5 - 24.9)
    // We'll aim for BMI of 22.0 (middle of healthy range)
    final targetBMI = 22.0;
    final targetWeight = targetBMI * (heightInMeters * heightInMeters);

    // Calculate weight to lose/gain
    final weightDifference = currentWeight - targetWeight;

    // Calculate calories needed to reach target BMI weight
    // Use Mifflin-St Jeor equation for BMR and adjust for target weight
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * targetWeight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * targetWeight) + (6.25 * height) - (5 * age) - 161;
    }

    // Apply activity factor to calculate TDEE for target weight
    double activityFactor = 1.2; // Sedentary default
    final activityLevel = widget.profile.activityLevel.toLowerCase();
    if (activityLevel == 'light')
      activityFactor = 1.375;
    else if (activityLevel == 'moderate')
      activityFactor = 1.55;
    else if (activityLevel == 'active')
      activityFactor = 1.725;
    else if (activityLevel == 'very active') activityFactor = 1.9;

    final targetCalories = bmr * activityFactor;

    // Apply BMI-based calorie adjustment to target calories
    double adjustedTargetCalories = targetCalories;
    if (currentBMI > 24.9) {
      // Weight loss: 0.5-1.0kg per week = 500-1000 calorie deficit
      // Scale deficit based on how overweight the person is
      final bmiExcess = currentBMI - 24.9;
      final deficitPerPoint =
          100.0; // 100 calories deficit per BMI point over 24.9
      final maxDeficit = 1000.0; // Maximum 1000 calorie deficit
      final deficit = (bmiExcess * deficitPerPoint).clamp(200.0, maxDeficit);
      adjustedTargetCalories = targetCalories - deficit;
      print('=== DEBUG: BMI excess: $bmiExcess, Calorie deficit: $deficit ===');
    } else if (currentBMI < 18.5) {
      // Weight gain: 0.25-0.5kg per week = 250-500 calorie surplus
      // Scale surplus based on how underweight the person is
      final bmiDeficit = 18.5 - currentBMI;
      final surplusPerPoint =
          150.0; // 150 calories surplus per BMI point under 18.5
      final maxSurplus = 500.0; // Maximum 500 calorie surplus
      final surplus = (bmiDeficit * surplusPerPoint).clamp(150.0, maxSurplus);
      adjustedTargetCalories = targetCalories + surplus;
      print(
          '=== DEBUG: BMI deficit: $bmiDeficit, Calorie surplus: $surplus ===');
    }
    // For normal BMI (18.5-24.9), keep maintenance calories

    print('=== DEBUG: Calculated target calories: $targetCalories ===');
    print('=== DEBUG: Adjusted target calories: $adjustedTargetCalories ===');
    print('=== DEBUG: BMR: $bmr ===');
    print('=== DEBUG: Activity factor: $activityFactor ===');

    // Determine weight goal based on BMI difference
    String weightGoal = 'Maintain Weight';
    if (currentBMI > 24.9) {
      weightGoal = 'Lose Weight';
    } else if (currentBMI < 18.5) {
      weightGoal = 'Gain Weight';
    }

    // Calculate time to reach goal (weeks)
    final weeksToGoal = weightDifference.abs() / 0.75; // 0.75kg per week

    final result = {
      'currentBMI': currentBMI,
      'targetBMI': targetBMI,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'weightDifference': weightDifference,
      'targetCalories': adjustedTargetCalories,
      'baseCalories':
          widget.profile.dailyNutrientRequirements['calories'] ?? 2000.0,
      'weeksToGoal': weeksToGoal,
      'weightGoal': weightGoal,
    };

    print('=== DEBUG: Final target values: $result ===');
    return result;
  }

  void _showNonFoodDialog(String foodName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Not a Food Item',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$foodName" doesn\'t appear to be a food item.',
              style: GoogleFonts.manrope(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This app only tracks food and nutrition. Please enter actual food items like:',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '• Fruits: apple, banana, orange\n'
              '• Vegetables: carrot, broccoli, tomato\n'
              '• Proteins: chicken, fish, eggs\n'
              '• Grains: rice, bread, pasta\n'
              '• Dairy: milk, cheese, yogurt',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.manrope(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearFoodForm();
            },
            child: Text(
              'Clear & Try Again',
              style: GoogleFonts.manrope(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFoodNameErrorDialog(String foodName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF0E2E20),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.greenAccent),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Food Not Found',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Color(0xFFE8F5E9),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$foodName" not found in our database.',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Would you like to enter nutrients manually?',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try common names like: apple, chicken, rice, banana',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Color(0xFFE8F5E9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: Color(0xFFE8F5E9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Retry with different name
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.manrope(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Show manual nutrient entry dialog
              _showManualNutrientDialog(foodName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Color(0xFF0A1A12),
              elevation: AppElevation.sm,
            ),
            child: Text(
              'Enter Manually',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A1A12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualNutrientDialog(String foodName) {
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final fiberController = TextEditingController();
    final sodiumController = TextEditingController();
    final sugarController = TextEditingController();
    final cholesterolController = TextEditingController();
    // Detailed fat controllers
    final monounsaturatedFatController = TextEditingController();
    final omega3Controller = TextEditingController();
    final omega6Controller = TextEditingController();
    final saturatedFatController = TextEditingController();
    final transFatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Nutrients for $foodName'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calories',
                    suffixText: 'kcal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Protein',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Carbohydrates',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Fat',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Detailed Fat Breakdown:',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: monounsaturatedFatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monounsaturated Fat',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: omega3Controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Omega-3',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: omega6Controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Omega-6',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: saturatedFatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saturated Fat',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: transFatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trans Fat',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: fiberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fiber',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: sodiumController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sodium',
                    suffixText: 'mg',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: sugarController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Added Sugar',
                    suffixText: 'g',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: cholesterolController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cholesterol',
                    suffixText: 'mg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final nutrients = {
                'calories': double.tryParse(caloriesController.text) ?? 0.0,
                'protein': double.tryParse(proteinController.text) ?? 0.0,
                'carbohydrates': double.tryParse(carbsController.text) ?? 0.0,
                'fat': double.tryParse(fatController.text) ?? 0.0,
                'fiber': double.tryParse(fiberController.text) ?? 0.0,
                'sodium': double.tryParse(sodiumController.text) ?? 0.0,
                'addedSugar': double.tryParse(sugarController.text) ?? 0.0,
                'cholesterol':
                    double.tryParse(cholesterolController.text) ?? 0.0,
                // Detailed fat breakdown
                'monounsaturatedFat':
                    double.tryParse(monounsaturatedFatController.text) ?? 0.0,
                'omega3': double.tryParse(omega3Controller.text) ?? 0.0,
                'omega6': double.tryParse(omega6Controller.text) ?? 0.0,
                'saturatedFat':
                    double.tryParse(saturatedFatController.text) ?? 0.0,
                'transFat': double.tryParse(transFatController.text) ?? 0.0,
              };
              _saveCustomFoodWithNutrients(foodName, nutrients);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _recalculateNutrients() {
    // Reset and calculate from today's scanned foods only
    _totalNutrients = {
      'calories': 0,
      'protein': 0,
      'carbohydrates': 0,
      'fat': 0,
      'totalFiber': 0,
      'solubleFiber': 0,
      'insolubleFiber': 0,
      'prebioticFiber': 0,
      'sodium': 0,
      'addedSugar': 0,
      'transFat': 0,
      'saturatedFat': 0,
      'refinedCarbs': 0,
      'cholesterol': 0,
      // Core Vitamins
      'vitaminA': 0,
      'vitaminC': 0,
      'vitaminD': 0,
      'vitaminB12': 0,
      // Full Vitamins Summary
      'vitaminE': 0,
      'vitaminK': 0,
      'vitaminB1': 0,
      'vitaminB2': 0,
      'vitaminB3': 0,
      'vitaminB5': 0,
      'vitaminB6': 0,
      'vitaminB7': 0,
      'vitaminB9': 0,
      'folate': 0,
      // Minerals Summary
      'calcium': 0,
      'iron': 0,
      'magnesium': 0,
      'potassium': 0,
      'zinc': 0,
      'phosphorus': 0,
      'copper': 0,
      'manganese': 0,
      'selenium': 0,
      // Other nutrients
      'omega3': 0,
    };

    // Only calculate from today's foods (not all historical foods)
    final now = DateTime.now();
    for (final foodInfo in _scannedFoods) {
      // For now, assume all foods are from today since HomeScreen only tracks current session
      _extractAndAddNutrients(foodInfo);
    }
  }

  Map<String, double> _calculateScientificHealthLimits() {
    // Get user data
    final weight = widget.profile.weight;
    final height = widget.profile.height;
    final age = widget.profile.age;
    final gender = widget.profile.gender;
    final activityLevel = widget.profile.activityLevel;
    final goal = widget.profile.goal;

    print(
        "Calculating scientific limits for: Weight=$weight, Height=$height, Age=$age, Gender=$gender, Activity=$activityLevel, Goal=$goal");

    // Calculate BMR using Mifflin-St Jeor Equation (most accurate for modern populations)
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // Activity multiplier
    double activityMultiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'lightly active':
        activityMultiplier = 1.375;
        break;
      case 'moderately active':
        activityMultiplier = 1.55;
        break;
      case 'very active':
        activityMultiplier = 1.725;
        break;
      case 'extra active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.375;
    }

    // Calculate TDEE (Total Daily Energy Expenditure)
    double tdee = bmr * activityMultiplier;

    // Adjust TDEE based on goal
    if (goal.toLowerCase().contains('lose') ||
        goal.toLowerCase().contains('weight loss')) {
      tdee *= 0.85; // 15% calorie deficit for weight loss
    } else if (goal.toLowerCase().contains('gain') ||
        goal.toLowerCase().contains('muscle')) {
      tdee *= 1.10; // 10% calorie surplus for muscle gain
    }
    // Maintain weight: no adjustment needed

    print("BMR: $bmr, TDEE: $tdee");

    // Calculate BMI to adjust recommendations
    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);
    print("BMI: $bmi");

    // WHO & AHA Guidelines with personalized adjustments:

    // 1. Added Sugar: WHO recommends < 10% of total energy intake
    //    Stricter for weight loss, more lenient for very active individuals
    double sugarPercentage = 0.10; // Base: 10% of TDEE

    if (goal.toLowerCase().contains('lose')) {
      sugarPercentage = 0.06; // Stricter: 6% for weight loss
    } else if (activityLevel.toLowerCase() == 'very active' ||
        activityLevel.toLowerCase() == 'extra active') {
      sugarPercentage = 0.08; // Slightly more for very active
    }

    if (bmi > 30) {
      sugarPercentage = 0.05; // Very strict for obesity
    } else if (bmi > 25) {
      sugarPercentage = 0.07; // Stricter for overweight
    }

    final addedSugarCalories = tdee * sugarPercentage;
    final addedSugar = addedSugarCalories / 4; // 1g sugar = 4 calories

    // 2. Trans Fat: WHO recommends < 1% of total energy intake
    //    Should be minimized regardless of profile
    final transFatCalories = tdee * 0.01;
    final transFat = transFatCalories / 9; // 1g fat = 9 calories

    // 3. Saturated Fat: AHA recommends 5-6% for heart health
    //    Adjust based on age and BMI
    double satFatPercentage = 0.07; // Base: 7%

    if (age > 50 || bmi > 25) {
      satFatPercentage = 0.06; // Stricter for older adults or overweight
    }

    if (goal.toLowerCase().contains('lose')) {
      satFatPercentage = 0.05; // Very strict for weight loss
    }

    final saturatedFatCalories = tdee * satFatPercentage;
    final saturatedFat = saturatedFatCalories / 9;

    // 4. Refined Carbs: Highly personalized based on activity and goals
    //    More active = can handle more refined carbs
    //    Weight loss = minimize refined carbs
    final totalCarbsNeeded =
        widget.profile.dailyNutrientRequirements['carbohydrates'] ??
            (tdee * 0.5 / 4);

    double refinedCarbPercentage = 0.15; // Base: 15% of total carbs

    if (goal.toLowerCase().contains('lose')) {
      refinedCarbPercentage = 0.10; // Minimize for weight loss
    } else if (goal.toLowerCase().contains('muscle') ||
        activityLevel.toLowerCase() == 'very active') {
      refinedCarbPercentage = 0.20; // Can handle more if very active
    }

    if (bmi > 25) {
      refinedCarbPercentage = 0.12; // Reduce for overweight individuals
    }

    final refinedCarbs = totalCarbsNeeded * refinedCarbPercentage;

    // Age-based adjustments (older adults need stricter limits)
    double ageMultiplier = 1.0;
    if (age > 60) {
      ageMultiplier = 0.85;
    } else if (age > 50) {
      ageMultiplier = 0.90;
    } else if (age < 25) {
      ageMultiplier = 1.10; // Young adults can handle slightly more
    }

    final result = {
      'addedSugar': (addedSugar * ageMultiplier).clamp(15.0, 60.0),
      'transFat': (transFat * ageMultiplier).clamp(0.5, 2.5),
      'saturatedFat': (saturatedFat * ageMultiplier).clamp(8.0, 30.0),
      'refinedCarbs': (refinedCarbs * ageMultiplier).clamp(20.0, 120.0),
    };

    print("Calculated scientific limits: $result");
    return result;
  }

  // Calculate health limits using AI
  Map<String, double> get _healthLimits {
    return _aiCalculatedLimits;
  }

  Map<String, double> _aiCalculatedLimits = {
    'addedSugar': 30.0, // Default values, will be updated by AI
    'transFat': 2.0,
    'saturatedFat': 20.0,
    'refinedCarbs': 50.0,
  };

  bool _isCalculatingLimits = false;

  Future<void> _calculateHealthLimitsWithAI() async {
    setState(() {
      print(
          "Profile data: Weight=${widget.profile.weight}, Height=${widget.profile.height}, Age=${widget.profile.age}, Gender=${widget.profile.gender}, Activity=${widget.profile.activityLevel}, State=${widget.profile.state}");
      _isCalculatingLimits = true;
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final profileInfo = '''
      User Profile:
      - Current Weight: ${widget.profile.weight}kg
      - Height: ${widget.profile.height}cm
      - Age: ${widget.profile.age} years
      - Gender: ${widget.profile.gender}
      - Activity Level: ${widget.profile.activityLevel}
      - Goal: ${widget.profile.goal}
      - State/Region: ${widget.profile.state}
      - Health Conditions: ${widget.profile.healthConditions.join(', ')}
      - Health Goals: ${widget.profile.healthGoals.keys.join(', ')}
      
      Please calculate personalized health limits based on this complete profile:
      1. Consider regional dietary patterns based on state/region
      2. Calculate ideal weight using medical standards (consider height, gender, age)
      3. Determine target weight (consider current vs ideal, age factors)
      4. Adjust calculations for health conditions:
         - Diabetes: Reduce carbs by 20%, sugar by 50%, increase fiber by 30%
         - High BP: Reduce sodium by 60%, increase potassium by 25%, magnesium by 20%
         - Obesity: Increase protein by 25%, fiber by 40%, reduce carbs by 15%, fat by 10%
         - Thyroid: Increase iodine by 50%, selenium by 30%, zinc by 20%
         - PCOS/PCOD: Increase fiber by 35%, protein by 15%, reduce carbs by 20%, vitamin D by 40%
         - Heart Health: Increase omega3 by 100%, fiber by 25%, reduce saturated fat by 30%, trans fat by 50%, sodium by 40%
       - Eye Sight: Increase vitamin A by 30%, vitamin C by 25%, vitamin E by 40%, zinc by 20%
       - Skin Issues: Increase vitamin A by 25%, vitamin C by 30%, vitamin E by 35%, zinc by 25%, omega3 by 40%
       - Fatigue: Increase iron by 30%, vitamin B12 by 40%, magnesium by 25%
       - Stress: Increase vitamin C by 40%, magnesium by 30%, vitamin B6 by 35%, omega3 by 50%
       - Depression: Increase vitamin D by 50%, omega3 by 60%, vitamin B12 by 30%, folate by 25%
       - Improve Focus: Increase omega3 by 40%, vitamin B6 by 30%, vitamin B12 by 25%, iron by 20%
       - Build Strength: Increase protein by 50%, vitamin D by 30%, magnesium by 25%, zinc by 20%
    4. Calculate daily limits for:
         - Added Sugar (WHO recommendations adjusted for weight/gender/goal/health conditions)
         - Trans Fat (WHO recommendations adjusted for health conditions)
         - Saturated Fat (AHA recommendations adjusted for age/BMI/goal/health conditions)
         - Refined Carbs (based on activity, goal, and health conditions)
         - Refined Carbs (based on activity level, goal, and target weight)
      
      Return only numerical values in this format:
      ADDED_SUGAR: [value in grams]
      TRANS_FAT: [value in grams]
      SATURATED_FAT: [value in grams]
      REFINED_CARBS: [value in grams]
      ''';

      final response = await model.generateContent([Content.text(profileInfo)]);

      final aiResponse = response.text ?? '';
      print("AI Response: $aiResponse");

      // Parse AI response
      final sugarMatch =
          RegExp(r'ADDED_SUGAR:\s*([\d.]+)').firstMatch(aiResponse);
      final transFatMatch =
          RegExp(r'TRANS_FAT:\s*([\d.]+)').firstMatch(aiResponse);
      final satFatMatch =
          RegExp(r'SATURATED_FAT:\s*([\d.]+)').firstMatch(aiResponse);
      final refinedCarbsMatch =
          RegExp(r'REFINED_CARBS:\s*([\d.]+)').firstMatch(aiResponse);

      if (mounted) {
        setState(() {
          print(
              "Profile data: Weight=${widget.profile.weight}, Height=${widget.profile.height}, Age=${widget.profile.age}, Gender=${widget.profile.gender}, Activity=${widget.profile.activityLevel}");
          if (sugarMatch != null) {
            _aiCalculatedLimits['addedSugar'] =
                double.parse(sugarMatch.group(1)!);
          }
          if (transFatMatch != null) {
            _aiCalculatedLimits['transFat'] =
                double.parse(transFatMatch.group(1)!);
          }
          if (satFatMatch != null) {
            _aiCalculatedLimits['saturatedFat'] =
                double.parse(satFatMatch.group(1)!);
          }
          if (refinedCarbsMatch != null) {
            _aiCalculatedLimits['refinedCarbs'] =
                double.parse(refinedCarbsMatch.group(1)!);
          }
          _isCalculatingLimits = false;
          print("AI Limits updated: $_aiCalculatedLimits");
        });
      }
    } catch (e) {
      print('Error calculating health limits with AI: $e');
      print('Falling back to scientific calculation...');

      if (mounted) {
        setState(() {
          // Use scientific calculation as fallback
          _aiCalculatedLimits = _calculateScientificHealthLimits();
          _isCalculatingLimits = false;
          print("Scientific fallback limits calculated: $_aiCalculatedLimits");
        });
      }
    }
  }

  void _showScientificNotification() {
    // Show user notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.science, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Using scientific calculations for health limits'),
            ),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _navigateToCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPage(
          cameras: widget.cameras,
          apiKey: _apiKey,
          userProfile: widget.profile, // Pass user profile
          onFoodAnalyzed: (nutritionInfo) {
            setState(() {
              _scannedFoods.add(nutritionInfo);
              _extractAndAddNutrients(nutritionInfo);
            });

            // Extract food name for feedback and history
            final foodName = _extractFoodName(nutritionInfo);

            // Add to history via callback
            if (widget.onFoodAdded != null) {
              print('HomeScreen: Calling onFoodAdded callback with $foodName');
              widget.onFoodAdded!(nutritionInfo, foodName);
            } else {
              print('HomeScreen: onFoodAdded callback is null!');
            }

            // Show success feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('$foodName added!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Trigger AI health limits calculation if needed
            if (!_isCalculatingLimits) {
              _calculateHealthLimitsWithAI();
            }
          },
        ),
      ),
    );
  } // Close _navigateToCamera method

  String _extractFoodName(String nutritionInfo) {
    // Try to extract food name from the new format
    final foodNameMatch =
        RegExp(r'FOOD_NAME:\s*(.+?)(?:\n|$)').firstMatch(nutritionInfo);
    if (foodNameMatch != null) {
      return foodNameMatch.group(1)!.trim();
    }

    // Fallback: extract first line if no FOOD_NAME format
    final lines = nutritionInfo.split('\n');
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      // If it looks like a food name (not a nutrient line)
      if (!firstLine.contains(':') &&
          !firstLine.contains('kcal') &&
          !firstLine.contains('g')) {
        return firstLine;
      }
    }

    return 'Food Item';
  }

  void _extractAndAddNutrients(String nutritionInfo) {
    print('=== DEBUG: Starting nutrient extraction ===');
    print('Input nutrition info length: ${nutritionInfo.length}');
    print('First 500 chars: ${nutritionInfo.substring(0, 500)}');

    // Enhanced extraction for the new structured format
    final caloriesMatch =
        RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final proteinMatch =
        RegExp(r'PROTEIN:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final carbMatch =
        RegExp(r'CARBOHYDRATES:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final fatMatch = RegExp(r'FAT:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false)
        .firstMatch(nutritionInfo);
    final fiberMatch =
        RegExp(r'FIBER:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final sodiumMatch =
        RegExp(r'SODIUM:\s*(\d+(?:\.\d+)?)\s*mg', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final sugarMatch = RegExp(r'ADDED[_\s]SUGAR:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final transFatMatch = RegExp(r'TRANS[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final satFatMatch = RegExp(r'SATURATED[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final refinedCarbMatch = RegExp(
            r'REFINED[_\s]CARBS:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);

    // Fiber breakdown extraction - more robust patterns
    final totalFiberMatch = RegExp(
            r'TOTAL[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final solubleFiberMatch = RegExp(
            r'SOLUBLE[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final insolubleFiberMatch = RegExp(
            r'INSOLUBLE[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final prebioticFiberMatch = RegExp(
            r'PREBIOTIC[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);

    // Detailed fat breakdown extraction - more robust patterns
    final monounsaturatedFatMatch = RegExp(
            r'MONOUNSATURATED[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final omega3Match =
        RegExp(r'OMEGA[-_]?3:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final omega6Match =
        RegExp(r'OMEGA[-_]?6:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false)
            .firstMatch(nutritionInfo);

    print('=== DEBUG: Testing specific matches ===');
    print('TOTAL_FIBER match: ${totalFiberMatch?.group(1) ?? "NULL"}');
    print(
        'MONOUNSATURATED_FAT match: ${monounsaturatedFatMatch?.group(1) ?? "NULL"}');
    print('OMEGA-3 match: ${omega3Match?.group(1) ?? "NULL"}');
    print(
        'VITAMIN A match: ${RegExp(r'VITAMIN[_\s]?A:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo)?.group(1) ?? "NULL"}');

    // Vitamins extraction - more robust patterns
    final vitaminAMatch = RegExp(
            r'VITAMIN[_\s]?A:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminCMatch = RegExp(r'VITAMIN[_\s]?C:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminDMatch = RegExp(
            r'VITAMIN[_\s]?D:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB12Match = RegExp(
            r'VITAMIN[_\s]?B12:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final folateMatch =
        RegExp(r'FOLATE:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final vitaminEMatch = RegExp(r'VITAMIN[_\s]?E:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminKMatch = RegExp(
            r'VITAMIN[_\s]?K:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB1Match = RegExp(
            r'VITAMIN[_\s]?B1:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB2Match = RegExp(
            r'VITAMIN[_\s]?B2:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB3Match = RegExp(
            r'VITAMIN[_\s]?B3:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB5Match = RegExp(
            r'VITAMIN[_\s]?B5:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB6Match = RegExp(
            r'VITAMIN[_\s]?B6:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB7Match = RegExp(
            r'VITAMIN[_\s]?B7:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);
    final vitaminB9Match = RegExp(
            r'VITAMIN[_\s]?B9:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);

    // Minerals extraction - more robust patterns
    final calciumMatch =
        RegExp(r'CALCIUM:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final ironMatch =
        RegExp(r'IRON:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final potassiumMatch =
        RegExp(r'POTASSIUM:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final magnesiumMatch =
        RegExp(r'MAGNESIUM:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final zincMatch =
        RegExp(r'ZINC:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final phosphorusMatch =
        RegExp(r'PHOSPHORUS:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final copperMatch =
        RegExp(r'COPPER:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final manganeseMatch =
        RegExp(r'MANGANESE:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);
    final seleniumMatch =
        RegExp(r'SELENIUM:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false)
            .firstMatch(nutritionInfo);

    // Other nutrients
    final cholesterolMatch = RegExp(r'CHOLESTEROL:\s*(\d+(?:\.\d+)?)\s*(?:mg)?',
            caseSensitive: false)
        .firstMatch(nutritionInfo);

    setState(() {
      // Macronutrients
      if (caloriesMatch != null) {
        final caloriesValue = double.parse(caloriesMatch.group(1)!);
        _totalNutrients['calories'] =
            (_totalNutrients['calories'] ?? 0) + caloriesValue;
        print('=== DEBUG: Calories extracted: $caloriesValue ===');
        print(
            '=== DEBUG: Total calories after adding: ${_totalNutrients['calories']} ===');
      } else {
        print('=== DEBUG: No calories match found in nutrition info ===');
      }
      if (proteinMatch != null) {
        _totalNutrients['protein'] = (_totalNutrients['protein'] ?? 0) +
            double.parse(proteinMatch.group(1)!);
      }
      if (carbMatch != null) {
        _totalNutrients['carbohydrates'] =
            (_totalNutrients['carbohydrates'] ?? 0) +
                double.parse(carbMatch.group(1)!);
      }
      if (fatMatch != null) {
        _totalNutrients['fat'] =
            (_totalNutrients['fat'] ?? 0) + double.parse(fatMatch.group(1)!);
      }
      if (fiberMatch != null) {
        _totalNutrients['fiber'] = (_totalNutrients['fiber'] ?? 0) +
            double.parse(fiberMatch.group(1)!);
      }

      // Fiber breakdown
      if (totalFiberMatch != null) {
        _totalNutrients['totalFiber'] = (_totalNutrients['totalFiber'] ?? 0) +
            double.parse(totalFiberMatch.group(1)!);
        print('✅ Extracted TOTAL FIBER: ${totalFiberMatch.group(1)}');
      } else {
        print(
            '❌ TOTAL FIBER not found in: ${nutritionInfo.substring(0, 200)}...');
      }
      if (solubleFiberMatch != null) {
        _totalNutrients['solubleFiber'] =
            (_totalNutrients['solubleFiber'] ?? 0) +
                double.parse(solubleFiberMatch.group(1)!);
        print('✅ Extracted SOLUBLE FIBER: ${solubleFiberMatch.group(1)}');
      }
      if (insolubleFiberMatch != null) {
        _totalNutrients['insolubleFiber'] =
            (_totalNutrients['insolubleFiber'] ?? 0) +
                double.parse(insolubleFiberMatch.group(1)!);
        print('✅ Extracted INSOLUBLE FIBER: ${insolubleFiberMatch.group(1)}');
      }
      if (prebioticFiberMatch != null) {
        _totalNutrients['prebioticFiber'] =
            (_totalNutrients['prebioticFiber'] ?? 0) +
                double.parse(prebioticFiberMatch.group(1)!);
        print('✅ Extracted PREBIOTIC FIBER: ${prebioticFiberMatch.group(1)}');
      }

      // Detailed fat breakdown
      if (monounsaturatedFatMatch != null) {
        _totalNutrients['monounsaturatedFat'] =
            (_totalNutrients['monounsaturatedFat'] ?? 0) +
                double.parse(monounsaturatedFatMatch.group(1)!);
        print(
            '✅ Extracted MONOUNSATURATED FAT: ${monounsaturatedFatMatch.group(1)}');
      }
      if (omega3Match != null) {
        _totalNutrients['omega3'] = (_totalNutrients['omega3'] ?? 0) +
            double.parse(omega3Match.group(1)!);
        print('✅ Extracted OMEGA-3: ${omega3Match.group(1)}');
      }
      if (omega6Match != null) {
        _totalNutrients['omega6'] = (_totalNutrients['omega6'] ?? 0) +
            double.parse(omega6Match.group(1)!);
        print('✅ Extracted OMEGA-6: ${omega6Match.group(1)}');
      }

      // Health-limiting nutrients
      if (sugarMatch != null) {
        _totalNutrients['addedSugar'] = (_totalNutrients['addedSugar'] ?? 0) +
            double.parse(sugarMatch.group(1)!);
      }
      if (transFatMatch != null) {
        _totalNutrients['transFat'] = (_totalNutrients['transFat'] ?? 0) +
            double.parse(transFatMatch.group(1)!);
      }
      if (satFatMatch != null) {
        _totalNutrients['saturatedFat'] =
            (_totalNutrients['saturatedFat'] ?? 0) +
                double.parse(satFatMatch.group(1)!);
      }
      if (refinedCarbMatch != null) {
        _totalNutrients['refinedCarbs'] =
            (_totalNutrients['refinedCarbs'] ?? 0) +
                double.parse(refinedCarbMatch.group(1)!);
      }

      // Vitamins
      if (vitaminAMatch != null) {
        _totalNutrients['vitaminA'] = (_totalNutrients['vitaminA'] ?? 0) +
            double.parse(vitaminAMatch.group(1)!);
        print('✅ Extracted VITAMIN A: ${vitaminAMatch.group(1)}');
      }
      if (vitaminCMatch != null) {
        _totalNutrients['vitaminC'] = (_totalNutrients['vitaminC'] ?? 0) +
            double.parse(vitaminCMatch.group(1)!);
        print('✅ Extracted VITAMIN C: ${vitaminCMatch.group(1)}');
      }
      if (vitaminDMatch != null) {
        _totalNutrients['vitaminD'] = (_totalNutrients['vitaminD'] ?? 0) +
            double.parse(vitaminDMatch.group(1)!);
        print('✅ Extracted VITAMIN D: ${vitaminDMatch.group(1)}');
      }
      if (vitaminB12Match != null) {
        _totalNutrients['vitaminB12'] = (_totalNutrients['vitaminB12'] ?? 0) +
            double.parse(vitaminB12Match.group(1)!);
        print('✅ Extracted VITAMIN B12: ${vitaminB12Match.group(1)}');
      }
      if (folateMatch != null) {
        _totalNutrients['folate'] = (_totalNutrients['folate'] ?? 0) +
            double.parse(folateMatch.group(1)!);
        print('✅ Extracted FOLATE: ${folateMatch.group(1)}');
      }
      if (vitaminEMatch != null) {
        _totalNutrients['vitaminE'] = (_totalNutrients['vitaminE'] ?? 0) +
            double.parse(vitaminEMatch.group(1)!);
        print('✅ Extracted VITAMIN E: ${vitaminEMatch.group(1)}');
      }
      if (vitaminKMatch != null) {
        _totalNutrients['vitaminK'] = (_totalNutrients['vitaminK'] ?? 0) +
            double.parse(vitaminKMatch.group(1)!);
        print('✅ Extracted VITAMIN K: ${vitaminKMatch.group(1)}');
      }
      if (vitaminB1Match != null) {
        _totalNutrients['vitaminB1'] = (_totalNutrients['vitaminB1'] ?? 0) +
            double.parse(vitaminB1Match.group(1)!);
        print('✅ Extracted VITAMIN B1: ${vitaminB1Match.group(1)}');
      }
      if (vitaminB2Match != null) {
        _totalNutrients['vitaminB2'] = (_totalNutrients['vitaminB2'] ?? 0) +
            double.parse(vitaminB2Match.group(1)!);
        print('✅ Extracted VITAMIN B2: ${vitaminB2Match.group(1)}');
      }
      if (vitaminB3Match != null) {
        _totalNutrients['vitaminB3'] = (_totalNutrients['vitaminB3'] ?? 0) +
            double.parse(vitaminB3Match.group(1)!);
        print('✅ Extracted VITAMIN B3: ${vitaminB3Match.group(1)}');
      }
      if (vitaminB5Match != null) {
        _totalNutrients['vitaminB5'] = (_totalNutrients['vitaminB5'] ?? 0) +
            double.parse(vitaminB5Match.group(1)!);
        print('✅ Extracted VITAMIN B5: ${vitaminB5Match.group(1)}');
      }
      if (vitaminB6Match != null) {
        _totalNutrients['vitaminB6'] = (_totalNutrients['vitaminB6'] ?? 0) +
            double.parse(vitaminB6Match.group(1)!);
        print('✅ Extracted VITAMIN B6: ${vitaminB6Match.group(1)}');
      }
      if (vitaminB7Match != null) {
        _totalNutrients['vitaminB7'] = (_totalNutrients['vitaminB7'] ?? 0) +
            double.parse(vitaminB7Match.group(1)!);
        print('✅ Extracted VITAMIN B7: ${vitaminB7Match.group(1)}');
      }
      if (vitaminB9Match != null) {
        _totalNutrients['vitaminB9'] = (_totalNutrients['vitaminB9'] ?? 0) +
            double.parse(vitaminB9Match.group(1)!);
        print('✅ Extracted VITAMIN B9: ${vitaminB9Match.group(1)}');
      }

      // Minerals
      if (sodiumMatch != null) {
        _totalNutrients['sodium'] = (_totalNutrients['sodium'] ?? 0) +
            double.parse(sodiumMatch.group(1)!);
      }
      if (calciumMatch != null) {
        _totalNutrients['calcium'] = (_totalNutrients['calcium'] ?? 0) +
            double.parse(calciumMatch.group(1)!);
      }
      if (ironMatch != null) {
        _totalNutrients['iron'] =
            (_totalNutrients['iron'] ?? 0) + double.parse(ironMatch.group(1)!);
      }
      if (potassiumMatch != null) {
        _totalNutrients['potassium'] = (_totalNutrients['potassium'] ?? 0) +
            double.parse(potassiumMatch.group(1)!);
      }
      if (magnesiumMatch != null) {
        _totalNutrients['magnesium'] = (_totalNutrients['magnesium'] ?? 0) +
            double.parse(magnesiumMatch.group(1)!);
      }
      if (zincMatch != null) {
        _totalNutrients['zinc'] =
            (_totalNutrients['zinc'] ?? 0) + double.parse(zincMatch.group(1)!);
      }
      if (phosphorusMatch != null) {
        _totalNutrients['phosphorus'] = (_totalNutrients['phosphorus'] ?? 0) +
            double.parse(phosphorusMatch.group(1)!);
      }
      if (copperMatch != null) {
        _totalNutrients['copper'] = (_totalNutrients['copper'] ?? 0) +
            double.parse(copperMatch.group(1)!);
      }
      if (manganeseMatch != null) {
        _totalNutrients['manganese'] = (_totalNutrients['manganese'] ?? 0) +
            double.parse(manganeseMatch.group(1)!);
      }
      if (seleniumMatch != null) {
        _totalNutrients['selenium'] = (_totalNutrients['selenium'] ?? 0) +
            double.parse(seleniumMatch.group(1)!);
      }

      // Other nutrients
      if (cholesterolMatch != null) {
        _totalNutrients['cholesterol'] = (_totalNutrients['cholesterol'] ?? 0) +
            double.parse(cholesterolMatch.group(1)!);
      }
      if (omega3Match != null) {
        _totalNutrients['omega3'] = (_totalNutrients['omega3'] ?? 0) +
            double.parse(omega3Match.group(1)!);
      }

      print('Updated nutrients: $_totalNutrients');
      print(
          'Health monitoring nutrients - Added Sugar: ${_totalNutrients['addedSugar']}, Trans Fat: ${_totalNutrients['transFat']}, Vitamin D: ${_totalNutrients['vitaminD']}, Omega-3: ${_totalNutrients['omega3']}, Total Fiber: ${_totalNutrients['totalFiber']}, Soluble Fiber: ${_totalNutrients['solubleFiber']}, Insoluble Fiber: ${_totalNutrients['insolubleFiber']}');
    });

    // Save updated data to persistent storage
    _saveUpdatedData();

    // Save daily intake after adding nutrients
    // _saveDailyIntake(); // DISABLED - MainTabScreen handles saving to prevent duplicates
  }

  Future<void> _saveUpdatedData() async {
    try {
      // History is now managed by MainTabScreen, no need to save here
      print('History management delegated to MainTabScreen');
    } catch (e) {
      print('Error in _saveUpdatedData: $e');
    }
  }

  Map<String, double> _extractNutrientsFromInfo(String foodInfo) {
    final nutrients = <String, double>{};

    // Extract nutrients from the new structured format
    final caloriesMatch =
        RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal').firstMatch(foodInfo);
    final proteinMatch =
        RegExp(r'PROTEIN:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final carbMatch =
        RegExp(r'CARBOHYDRATES:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final fatMatch = RegExp(r'FAT:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final fiberMatch =
        RegExp(r'FIBER:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final sodiumMatch =
        RegExp(r'SODIUM:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final sugarMatch =
        RegExp(r'ADDED SUGAR:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final transFatMatch =
        RegExp(r'TRANS FAT:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final satFatMatch =
        RegExp(r'SATURATED FAT:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final refinedCarbMatch =
        RegExp(r'REFINED CARBS:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);

    // Vitamins
    final vitaminAMatch =
        RegExp(r'VITAMIN A:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);
    final vitaminCMatch =
        RegExp(r'VITAMIN C:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminDMatch =
        RegExp(r'VITAMIN D:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);
    final vitaminB12Match =
        RegExp(r'VITAMIN B12:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);
    final folateMatch =
        RegExp(r'FOLATE:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);

    // Minerals
    final calciumMatch =
        RegExp(r'CALCIUM:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final ironMatch =
        RegExp(r'IRON:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final potassiumMatch =
        RegExp(r'POTASSIUM:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final magnesiumMatch =
        RegExp(r'MAGNESIUM:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final zincMatch =
        RegExp(r'ZINC:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);

    // Other nutrients
    final cholesterolMatch =
        RegExp(r'CHOLESTEROL:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final omega3Match =
        RegExp(r'OMEGA-3:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);

    // Add all missing vitamins and minerals for complete tracking
    // Full Vitamins Summary
    final vitaminEMatch =
        RegExp(r'VITAMIN E:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminKMatch =
        RegExp(r'VITAMIN K:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);
    final vitaminB1Match =
        RegExp(r'VITAMIN B1:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminB2Match =
        RegExp(r'VITAMIN B2:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminB3Match =
        RegExp(r'VITAMIN B3:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminB5Match =
        RegExp(r'VITAMIN B5:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminB6Match =
        RegExp(r'VITAMIN B6:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final vitaminB7Match =
        RegExp(r'VITAMIN B7:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);
    final vitaminB9Match =
        RegExp(r'VITAMIN B9:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);

    // Fiber breakdown
    final totalFiberMatch =
        RegExp(r'TOTAL FIBER:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final solubleFiberMatch =
        RegExp(r'SOLUBLE FIBER:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final insolubleFiberMatch =
        RegExp(r'INSOLUBLE FIBER:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);
    final prebioticFiberMatch =
        RegExp(r'PREBIOTIC FIBER:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(foodInfo);

    // Extract all nutrients
    if (caloriesMatch != null)
      nutrients['calories'] = double.parse(caloriesMatch.group(1)!);
    if (proteinMatch != null)
      nutrients['protein'] = double.parse(proteinMatch.group(1)!);
    if (carbMatch != null)
      nutrients['carbohydrates'] = double.parse(carbMatch.group(1)!);
    if (fatMatch != null) nutrients['fat'] = double.parse(fatMatch.group(1)!);
    if (fiberMatch != null)
      nutrients['fiber'] = double.parse(fiberMatch.group(1)!);
    if (sodiumMatch != null)
      nutrients['sodium'] = double.parse(sodiumMatch.group(1)!);
    if (sugarMatch != null)
      nutrients['addedSugar'] = double.parse(sugarMatch.group(1)!);
    if (transFatMatch != null)
      nutrients['transFat'] = double.parse(transFatMatch.group(1)!);
    if (satFatMatch != null)
      nutrients['saturatedFat'] = double.parse(satFatMatch.group(1)!);
    if (refinedCarbMatch != null)
      nutrients['refinedCarbs'] = double.parse(refinedCarbMatch.group(1)!);

    // Core Vitamins
    if (vitaminAMatch != null)
      nutrients['vitaminA'] = double.parse(vitaminAMatch.group(1)!);
    if (vitaminCMatch != null)
      nutrients['vitaminC'] = double.parse(vitaminCMatch.group(1)!);
    if (vitaminDMatch != null)
      nutrients['vitaminD'] = double.parse(vitaminDMatch.group(1)!);
    if (vitaminB12Match != null)
      nutrients['vitaminB12'] = double.parse(vitaminB12Match.group(1)!);

    // Full Vitamins Summary
    if (vitaminEMatch != null)
      nutrients['vitaminE'] = double.parse(vitaminEMatch.group(1)!);
    if (vitaminKMatch != null)
      nutrients['vitaminK'] = double.parse(vitaminKMatch.group(1)!);
    if (vitaminB1Match != null)
      nutrients['vitaminB1'] = double.parse(vitaminB1Match.group(1)!);
    if (vitaminB2Match != null)
      nutrients['vitaminB2'] = double.parse(vitaminB2Match.group(1)!);
    if (vitaminB3Match != null)
      nutrients['vitaminB3'] = double.parse(vitaminB3Match.group(1)!);
    if (vitaminB5Match != null)
      nutrients['vitaminB5'] = double.parse(vitaminB5Match.group(1)!);
    if (vitaminB6Match != null)
      nutrients['vitaminB6'] = double.parse(vitaminB6Match.group(1)!);
    if (vitaminB7Match != null)
      nutrients['vitaminB7'] = double.parse(vitaminB7Match.group(1)!);
    if (vitaminB9Match != null)
      nutrients['vitaminB9'] = double.parse(vitaminB9Match.group(1)!);
    if (folateMatch != null)
      nutrients['folate'] = double.parse(folateMatch.group(1)!);

    // Fiber Breakdown
    if (totalFiberMatch != null)
      nutrients['totalFiber'] = double.parse(totalFiberMatch.group(1)!);
    if (solubleFiberMatch != null)
      nutrients['solubleFiber'] = double.parse(solubleFiberMatch.group(1)!);
    if (insolubleFiberMatch != null)
      nutrients['insolubleFiber'] = double.parse(insolubleFiberMatch.group(1)!);
    if (prebioticFiberMatch != null)
      nutrients['prebioticFiber'] = double.parse(prebioticFiberMatch.group(1)!);

    // Minerals Summary
    if (calciumMatch != null)
      nutrients['calcium'] = double.parse(calciumMatch.group(1)!);
    if (ironMatch != null)
      nutrients['iron'] = double.parse(ironMatch.group(1)!);
    if (potassiumMatch != null)
      nutrients['potassium'] = double.parse(potassiumMatch.group(1)!);
    if (magnesiumMatch != null)
      nutrients['magnesium'] = double.parse(magnesiumMatch.group(1)!);
    if (zincMatch != null)
      nutrients['zinc'] = double.parse(zincMatch.group(1)!);

    // Additional minerals extraction patterns
    final phosphorusMatch =
        RegExp(r'PHOSPHORUS:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final copperMatch =
        RegExp(r'COPPER:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final manganeseMatch =
        RegExp(r'MANGANESE:\s*(\d+(?:\.\d+)?)\s*mg').firstMatch(foodInfo);
    final seleniumMatch =
        RegExp(r'SELENIUM:\s*(\d+(?:\.\d+)?)\s*mcg').firstMatch(foodInfo);

    if (phosphorusMatch != null)
      nutrients['phosphorus'] = double.parse(phosphorusMatch.group(1)!);
    if (copperMatch != null)
      nutrients['copper'] = double.parse(copperMatch.group(1)!);
    if (manganeseMatch != null)
      nutrients['manganese'] = double.parse(manganeseMatch.group(1)!);
    if (seleniumMatch != null)
      nutrients['selenium'] = double.parse(seleniumMatch.group(1)!);

    // Other nutrients
    if (cholesterolMatch != null)
      nutrients['cholesterol'] = double.parse(cholesterolMatch.group(1)!);
    if (omega3Match != null)
      nutrients['omega3'] = double.parse(omega3Match.group(1)!);

    return nutrients;
  }

  double _getProgressPercentage(String nutrient) {
    final daily = widget.profile.dailyNutrientRequirements[nutrient] ?? 1;
    final consumed = _totalNutrients[nutrient] ?? 0;
    return (consumed / daily * 100).clamp(0.0, 100.0);
  }

  Widget _buildNutrientBox(String name, String emoji, int consumed, int daily,
      String unit, Color color) {
    final percentage = _getProgressPercentage(name.toLowerCase());
    final isOverGoal = percentage >= 100;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color(0xFF0E2E20),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isOverGoal ? Colors.greenAccent : color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$consumed / $daily $unit',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isOverGoal ? AppColors.error : AppColors.info,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: isOverGoal ? AppColors.error : color,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: isOverGoal
                      ? AppColors.error.withOpacity(0.8)
                      : AppColors.info,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${percentage.round()}%',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOverGoal ? AppColors.error : AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthLimitCard(
      String label, double current, double limit, String unit) {
    final percentage = (current / limit * 100).clamp(0.0, 100.0);
    final isOverLimit = percentage >= 100;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Color(0xFF0E2E20),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8F5E9),
                ),
              ),
              Text(
                '${percentage.round()}%',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                current.toStringAsFixed(1),
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE8F5E9),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '/ ${limit.toInt()}$unit',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    color: Color(0xFFE8F5E9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: isOverLimit
                      ? AppColors.error.withOpacity(0.8)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularCalorieDisplay() {
    final targets = _calculateTargetValues();
    final caloriesConsumed = _totalNutrients['calories'] ?? 0.0;
    final targetCaloriesFromTargets = targets['targetCalories'];
    final baseCaloriesFromDaily = widget
        .profile.dailyNutrientRequirements['calories']; // Use getter directly
    final caloriesRequired =
        targetCaloriesFromTargets ?? baseCaloriesFromDaily ?? 2000.0;
    final percentage =
        (caloriesConsumed / caloriesRequired * 100).clamp(0.0, 100.0);
    final remaining = caloriesRequired - caloriesConsumed;

    print('=== DEBUG: Calorie Display Values ===');
    print('=== DEBUG: Calories consumed: $caloriesConsumed ===');
    print(
        '=== DEBUG: Target calories from targets: $targetCaloriesFromTargets ===');
    print(
        '=== DEBUG: Base calories from daily (getter): $baseCaloriesFromDaily ===');
    print('=== DEBUG: Final calories required: $caloriesRequired ===');
    print('=== DEBUG: Profile weight: ${widget.profile.weight} ===');
    print(
        '=== DEBUG: Fresh daily requirements: ${widget.profile.dailyNutrientRequirements} ===');

    return Container(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLight,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 100 ? AppColors.error : AppColors.success,
              ),
            ),
          ),
          // Center content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 24,
                color: percentage >= 100 ? AppColors.error : AppColors.success,
              ),
              const SizedBox(height: 4),
              Text(
                '${caloriesConsumed.toInt()}',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE8F5E9),
                ),
              ),
              Text(
                '/ ${caloriesRequired.toInt()} kcal',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: Color(0xFFE8F5E9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${percentage.round()}%',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: percentage >= 100 ? Colors.red : Colors.greenAccent,
                ),
              ),
              if (remaining > 0)
                Text(
                  '${remaining.toInt()} left',
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    color: Color(0xFFE8F5E9),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to create 2-column grid of nutrient cards
  List<Widget> _buildNutrientGrid(List<Widget> nutrientCards) {
    List<Widget> rows = [];
    for (int i = 0; i < nutrientCards.length; i += 2) {
      if (i + 1 < nutrientCards.length) {
        // Pair of cards
        rows.add(
          Row(
            children: [
              Expanded(child: nutrientCards[i]),
              const SizedBox(width: 8),
              Expanded(child: nutrientCards[i + 1]),
            ],
          ),
        );
      } else {
        // Single card (odd number)
        rows.add(
          Row(
            children: [
              Expanded(child: nutrientCards[i]),
              const Expanded(child: SizedBox()), // Empty space for alignment
            ],
          ),
        );
      }
      // Add spacing between rows
      if (i + 2 < nutrientCards.length) {
        rows.add(const SizedBox(height: 8));
      }
    }
    return rows;
  }

  Widget _buildNutrientProgressCard(
      String label, double current, double daily, String unit, String emoji) {
    final percentage = (current / daily * 100).clamp(0.0, 100.0);
    final isOverGoal = percentage >= 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Color(0xFF0E2E20),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE8F5E9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOverGoal
                      ? Colors.red.withOpacity(0.1)
                      : Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${percentage.toInt()}%',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isOverGoal ? Colors.red : Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Enhanced Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (percentage / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOverGoal
                              ? [Colors.red.shade400, Colors.red.shade600]
                              : [
                                  const Color(0xFF10B981),
                                  const Color(0xFF059669)
                                ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${current.toStringAsFixed(current < 10 ? 1 : 0)}$unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOverGoal ? Colors.red : const Color(0xFF374151),
                ),
              ),
              Text(
                'Goal: ${daily.toStringAsFixed(0)}$unit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Food Creator Methods
  void _saveCustomFood() async {
    print('=== DEBUG: _saveCustomFood called ===');
    if (!_formKey.currentState!.validate()) {
      print('=== DEBUG: Form validation failed ===');
      return;
    }

    final foodName = _foodNameController.text.trim();
    final quantity =
        double.tryParse(_quantityController.text) ?? 100.0; // Default to 100g

    print('=== DEBUG: Food name: $foodName, quantity: $quantity ===');

    setState(() => _isLoading = true);

    try {
      // Check if it's likely a food item first
      if (!_isLikelyFood(foodName.toLowerCase().trim())) {
        setState(() => _isLoading = false);
        _showNonFoodDialog(foodName);
        return;
      }

      print('=== DEBUG: Fetching nutrients from API ===');
      // Fetch nutrients from API
      final foodData = await _fetchFoodNutrients(foodName, quantity);

      print(
          '=== DEBUG: API returned: ${foodData != null ? "SUCCESS" : "NULL"} ===');
      if (foodData == null) {
        setState(() => _isLoading = false);
        _showFoodNameErrorDialog(foodName);
        return;
      }

      print('=== DEBUG: Nutrients data: ${foodData['nutrients']} ===');
      // If valid, proceed with saving using API data
      _saveCustomFoodWithNutrients(foodName, foodData['nutrients']);
    } catch (e) {
      print('=== DEBUG: Exception in _saveCustomFood: $e ===');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text('Error fetching food data: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveCustomFoodWithNutrients(
      String foodName, Map<String, dynamic> nutrients) async {
    try {
      print('=== DEBUG: _saveCustomFoodWithNutrients called ===');
      print('=== DEBUG: Food name: $foodName ===');
      print('=== DEBUG: Calories from nutrients: ${nutrients['calories']} ===');

      // Create food info string similar to camera output with detailed fat breakdown
      final foodInfo = '''FOOD_NAME: $foodName
CALORIES: ${nutrients['calories']?.round()} kcal
PROTEIN: ${nutrients['protein']?.round()} g
CARBOHYDRATES: ${nutrients['carbohydrates']?.round()} g
FAT: ${nutrients['fat']?.round()} g
FIBER: ${nutrients['fiber']?.round()} g
SODIUM: ${nutrients['sodium']?.round()} mg
ADDED SUGAR: ${nutrients['addedSugar']?.round()} g
TRANS FAT: ${nutrients['transFat']?.round()} g
SATURATED FAT: ${nutrients['saturatedFat']?.round()} g
REFINED CARBS: ${nutrients['refinedCarbs']?.round()} g
CHOLESTEROL: ${nutrients['cholesterol']?.round()} mg

// Fiber Breakdown
TOTAL FIBER: ${nutrients['totalFiber']?.round()} g
SOLUBLE FIBER: ${nutrients['solubleFiber']?.round()} g
INSOLUBLE FIBER: ${nutrients['insolubleFiber']?.round()} g
PREBIOTIC FIBER: ${nutrients['prebioticFiber']?.round()} g

// Fat Breakdown
MONOUNSATURATED FAT: ${nutrients['monounsaturatedFat']?.round()} g
OMEGA-3: ${nutrients['omega3']?.round()} g
OMEGA-6: ${nutrients['omega6']?.round()} g

// Vitamins (Complete Set)
VITAMIN A: ${nutrients['vitaminA']?.round()} mcg
VITAMIN C: ${nutrients['vitaminC']?.round()} mg
VITAMIN D: ${nutrients['vitaminD']?.round()} mcg
VITAMIN E: ${nutrients['vitaminE']?.round()} mg
VITAMIN K: ${nutrients['vitaminK']?.round()} mcg
VITAMIN B1: ${nutrients['vitaminB1']?.round()} mg
VITAMIN B2: ${nutrients['vitaminB2']?.round()} mg
VITAMIN B3: ${nutrients['vitaminB3']?.round()} mg
VITAMIN B5: ${nutrients['vitaminB5']?.round()} mg
VITAMIN B6: ${nutrients['vitaminB6']?.round()} mg
VITAMIN B7: ${nutrients['vitaminB7']?.round()} mcg
VITAMIN B9: ${nutrients['vitaminB9']?.round()} mcg
VITAMIN B12: ${nutrients['vitaminB12']?.round()} mcg
FOLATE: ${nutrients['folate']?.round()} mcg

// Minerals (Complete Set)
CALCIUM: ${nutrients['calcium']?.round()} mg
IRON: ${nutrients['iron']?.round()} mg
POTASSIUM: ${nutrients['potassium']?.round()} mg
MAGNESIUM: ${nutrients['magnesium']?.round()} mg
ZINC: ${nutrients['zinc']?.round()} mg
PHOSPHORUS: ${nutrients['phosphorus']?.round()} mg
COPPER: ${nutrients['copper']?.round()} mg
MANGANESE: ${nutrients['manganese']?.round()} mg
SELENIUM: ${nutrients['selenium']?.round()} mcg''';

      setState(() {
        _scannedFoods.add(foodInfo);
        _extractAndAddNutrients(foodInfo);
        print('Custom food added: $foodName');
      });

      // Add to history via callback
      if (widget.onFoodAdded != null) {
        print('HomeScreen: Calling onFoodAdded callback with $foodName');
        widget.onFoodAdded!(foodInfo, foodName);
      } else {
        print('HomeScreen: onFoodAdded callback is null!');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text('$foodName added!'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      _clearFoodForm();
      setState(() => _showFoodForm = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text('Error: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearFoodForm() {
    _formKey.currentState?.reset();
    _foodNameController.clear();
    _quantityController.clear();
    _searchController.clear();
    _searchResults.clear();
  }

  Future<void> _searchFood() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await FoodApiService.searchFood(query, _apiKey);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching food: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchAndFillFood(String foodName) async {
    if (foodName.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await FoodApiService.searchFood(foodName, _apiKey);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      // If search fails, proceed with existing manual flow
      _saveCustomFood();
    }
  }

  void _selectFoodItem(FoodItem foodItem) {
    setState(() {
      _foodNameController.text = foodItem.name;
      _quantityController.text = '100'; // Default to 100g
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _scrollToFoodForm() {
    print('=== DEBUG: _scrollToFoodForm called ===');
    print(
        '=== DEBUG: _foodFormKey.currentContext: ${_foodFormKey.currentContext} ===');
    print('=== DEBUG: _showFoodForm: $_showFoodForm ===');

    if (_foodFormKey.currentContext != null) {
      print('=== DEBUG: Context found, scrolling to food form ===');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          _foodFormKey.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          alignment: 0.2, // Scroll to 20% from top
        );
      });
    } else {
      print('=== DEBUG: Context is null, retrying after delay ===');
      // Retry after a short delay to allow the form to render
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_foodFormKey.currentContext != null) {
          print('=== DEBUG: Retry successful, now scrolling ===');
          Scrollable.ensureVisible(
            _foodFormKey.currentContext!,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        } else {
          print('=== DEBUG: Retry failed, context still null ===');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate target values and related variables
    final targets = _calculateTargetValues();
    final weightGoal = targets['weightGoal'] ?? 'Maintain Weight';
    final currentBMI = targets['currentBMI'] ?? 0.0;

    // Determine goal color and change verb/icon based on BMI
    Color goalColor = AppColors.info;
    String changeVerb = 'change';
    String changeIcon = '🔄';
    String calorieType = 'adjustment';

    if (currentBMI > 24.9) {
      goalColor = AppColors.warning;
      changeVerb = 'lose';
      changeIcon = '📉';
      calorieType = 'deficit';
    } else if (currentBMI < 18.5) {
      goalColor = AppColors.success;
      changeVerb = 'gain';
      changeIcon = '📈';
      calorieType = 'surplus';
    }

    // Calculate weight change potential based on BMI
    final baseCalories = targets['baseCalories'] ?? 2000.0;
    final targetCalories = targets['targetCalories'] ?? 2000.0;

    final weightChangePotential = {
      'safeWeeklyChange':
          currentBMI > 24.9 ? 0.75 : (currentBMI < 18.5 ? 0.5 : 0.0),
      'safeMonthlyChange':
          currentBMI > 24.9 ? 3.0 : (currentBMI < 18.5 ? 2.0 : 0.0),
      'weeksToTarget': (targets['weeksToGoal'] ?? 0).round(),
      'recommendedCalorieAdjustment': (targetCalories - baseCalories).round(),
      'targetDate': (targets['weeksToGoal'] ?? 0) > 0
          ? DateTime.now()
              .add(Duration(days: ((targets['weeksToGoal'] ?? 0) * 7).round()))
          : null,
    };

    return Scaffold(
      backgroundColor: Color(0xFF0A1A12),
      appBar: AppBar(
        title: Text(
          'Nutrition Tracker',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFFE8F5E9),
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF0E2E20),
        foregroundColor: Color(0xFFE8F5E9),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSetupPage(
                    cameras: widget.cameras,
                    existingProfile: widget.profile,
                    onProfileSaved: (updatedProfile) {
                      print(
                          'HomeScreen: Profile updated from ${widget.profile.weight}kg to ${updatedProfile.weight}kg');
                      print(
                          'Health conditions updated: ${widget.profile.healthConditions} -> ${updatedProfile.healthConditions}');
                      // Update profile in parent widget first to trigger widget rebuild
                      if (widget.onProfileUpdated != null) {
                        widget.onProfileUpdated!(updatedProfile);
                      }
                      // Navigate back with updated profile
                      Navigator.of(context).pop();
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Profile updated successfully! Nutrient requirements recalculated.',
                                  style: GoogleFonts.manrope(),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Weight Update Reminder Block - Only show when visible
            if (_showWeightUpdateBlock)
              Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.warning.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: AppColors.warning, size: 24),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Weight Update Required!',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'It\'s been 15 days! Time to update your weight for accurate nutrition tracking.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => WeightUpdateDialog(
                              currentProfile: widget.profile,
                              onWeightUpdated: (updatedProfile) {
                                if (widget.onProfileUpdated != null) {
                                  widget.onProfileUpdated!(updatedProfile);
                                }
                                // Hide block and save weight update time
                                _hideWeightUpdateBlock();
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.monitor_weight, size: 20),
                        label: Text(
                          'Update Weight Now',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          elevation: AppElevation.sm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Daily Nutrient Requirements Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Your Daily Nutrient Requirements',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      '🔥 Target Calories: ${targetCalories.round()} kcal\n'
                      '🥩 Protein: ${widget.profile.dailyNutrientRequirements['protein']?.round()}g\n'
                      '🍞 Carbs: ${widget.profile.dailyNutrientRequirements['carbohydrates']?.round()}g\n'
                      '🥑 Fat: ${widget.profile.dailyNutrientRequirements['fat']?.round()}g\n'
                      '🌾 Fiber: ${widget.profile.dailyNutrientRequirements['fiber']?.round()}g\n'
                      '💧 Water: ${(widget.profile.dailyNutrientRequirements['water']! * 1000).round()}ml',
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            // BMI-Based Target Values Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Color(0xFF0E2E20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your BMI-Based Targets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE8F5E9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.monitor_weight,
                          color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Goal: $weightGoal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📊 Current BMI: ${targets['currentBMI']?.toStringAsFixed(1)}\n'
                        '🎯 Target BMI: ${targets['targetBMI']?.toStringAsFixed(1)}\n'
                        '⚖️ Current Weight: ${targets['currentWeight']?.round()} kg\n'
                        '🏆 Target Weight: ${targets['targetWeight']?.round()} kg\n'
                        '📈 Weight to $changeVerb: ${targets['weightDifference']?.abs()?.round()} kg\n'
                        '⏱️ Original Est. Time: ${targets['weeksToGoal']?.round()} weeks\n'
                        '$changeIcon Safe Weekly $changeVerb: ${weightChangePotential['safeWeeklyChange']?.toStringAsFixed(1)} kg\n'
                        '📅 Safe Monthly $changeVerb: ${weightChangePotential['safeMonthlyChange']?.toStringAsFixed(1)} kg\n'
                        '🎯 Realistic Time to Target: ${weightChangePotential['weeksToTarget']} weeks\n',
                        // '📉 Recommended Calorie $calorieType: ${weightChangePotential['recommendedCalorieAdjustment']} kcal/day\n'
                        // '📅 Target Date: ${_formatTargetDate(weightChangePotential['targetDate'])}',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFFE8F5E9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Circular Calorie Display (moved here)
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Color(0xFF0E2E20),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'CALORIE TRACKER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE8F5E9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Circular calorie display
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(_totalNutrients['calories'] ?? 0.0).round()}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              Text(
                                'of ${targetCalories.round()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE8F5E9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${((_totalNutrients['calories'] ?? 0.0) / targetCalories * 100).round()}%',
                              style: TextStyle(
                                color: Color(0xFF0A1A12),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Food Form Section (conditionally shown)
            if (_showFoodForm)
              Container(
                key: _foodFormKey,
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Color(0xFF0E2E20),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.3), width: 1),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.restaurant_menu,
                              color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ADD CUSTOM FOOD',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE8F5E9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Manual Entry Section
                      Text(
                        'Or enter manually:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE8F5E9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _foodNameController,
                        decoration: InputDecoration(
                          labelText: 'Food Name',
                          hintText:
                              'e.g., Apple, Chicken Breast, Rice (AI will find nutrition)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.restaurant),
                          suffixIcon: _isSearching
                              ? Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter food name';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Clear search results when user types
                          if (_searchResults.isNotEmpty) {
                            setState(() {
                              _searchResults.clear();
                            });
                          }
                        },
                        onFieldSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _searchAndFillFood(value.trim());
                          }
                        },
                      ),
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF0E2E20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF0E2E20),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                  border: Border.all(
                                      color:
                                          Colors.greenAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  '🤖 AI Suggestions (tap to select)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE8F5E9),
                                  ),
                                ),
                              ),
                              ..._searchResults.asMap().entries.map((entry) {
                                final index = entry.key;
                                final foodItem = entry.value;
                                return InkWell(
                                  onTap: () => _selectFoodItem(foodItem),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color:
                                              index < _searchResults.length - 1
                                                  ? Colors.greenAccent
                                                      .withOpacity(0.2)
                                                  : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                foodItem.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${foodItem.calories.round()} kcal | ${foodItem.protein.round()}g protein | ${foodItem.carbohydrates.round()}g carbs',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFE8F5E9),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.add_circle,
                                            color: Colors.greenAccent,
                                            size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          hintText: '100',
                          suffixText: 'grams',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          if (double.tryParse(value) == null ||
                              double.tryParse(value)! <= 0) {
                            return 'Please enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '📊 Nutrients will be fetched automatically from our database',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE8F5E9),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _clearFoodForm,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveCustomFood,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Fetch & Add Food'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Macronutrients Progress Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Color(0xFF0E2E20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.local_dining,
                        color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('MACRONUTRIENTS PROGRESS',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8F5E9))))
                  ]),
                  const SizedBox(height: 8),
                  ..._buildNutrientGrid([
                    _buildNutrientProgressCard(
                        'Protein',
                        _totalNutrients['protein'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['protein'] ??
                            50,
                        'g',
                        '🥩'),
                    _buildNutrientProgressCard(
                        'Carbohydrates',
                        _totalNutrients['carbohydrates'] ?? 0.0,
                        widget.profile
                                .dailyNutrientRequirements['carbohydrates'] ??
                            300,
                        'g',
                        '🍞'),
                    _buildNutrientProgressCard(
                        'Fat',
                        _totalNutrients['fat'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['fat'] ?? 70,
                        'g',
                        '🥑'),
                    _buildNutrientProgressCard(
                        'Fiber',
                        _totalNutrients['fiber'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['fiber'] ?? 30,
                        'g',
                        '🌾'),
                  ]),
                ],
              ),
            ),

            // Fiber Breakdown Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Color(0xFF0E2E20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.grain, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('FIBER BREAKDOWN',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8F5E9))))
                  ]),
                  const SizedBox(height: 8),
                  ..._buildNutrientGrid([
                    _buildNutrientProgressCard(
                        'Total Fiber',
                        _totalNutrients['totalFiber'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['fiber'] ?? 30,
                        'g',
                        '🌾'),
                    _buildNutrientProgressCard(
                        'Soluble Fiber',
                        _totalNutrients['solubleFiber'] ?? 0.0,
                        (widget.profile.dailyNutrientRequirements['fiber'] ??
                                30) *
                            0.4,
                        'g',
                        '🥦'),
                    _buildNutrientProgressCard(
                        'Insoluble Fiber',
                        _totalNutrients['insolubleFiber'] ?? 0.0,
                        (widget.profile.dailyNutrientRequirements['fiber'] ??
                                30) *
                            0.6,
                        'g',
                        '🥬'),
                  ]),
                ],
              ),
            ),

            // Fat Breakdown Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Color(0xFF0E2E20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.opacity, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('FAT BREAKDOWN',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8F5E9))))
                  ]),
                  const SizedBox(height: 8),
                  ..._buildNutrientGrid([
                    _buildNutrientProgressCard(
                        'Monounsaturated Fat',
                        _totalNutrients['monounsaturatedFat'] ?? 0.0,
                        (widget.profile.dailyNutrientRequirements['fat'] ??
                                70) *
                            0.4,
                        'g',
                        '🫒'),
                    _buildNutrientProgressCard('Omega-3',
                        _totalNutrients['omega3'] ?? 0.0, 2.0, 'g', '🐟'),
                    _buildNutrientProgressCard('Omega-6',
                        _totalNutrients['omega6'] ?? 0.0, 10.0, 'g', '🌻'),
                    _buildNutrientProgressCard(
                        'Saturated Fat',
                        _totalNutrients['saturatedFat'] ?? 0.0,
                        (widget.profile.dailyNutrientRequirements['fat'] ??
                                70) *
                            0.3,
                        'g',
                        '🥓'),
                    _buildNutrientProgressCard('Trans Fat',
                        _totalNutrients['transFat'] ?? 0.0, 2.0, 'g', '⚠️'),
                  ]),
                ],
              ),
            ),

            // Vitamins Progress Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Color(0xFF0E2E20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.medication, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('VITAMINS PROGRESS',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8F5E9))))
                  ]),
                  const SizedBox(height: 8),
                  ..._buildNutrientGrid([
                    _buildNutrientProgressCard(
                        'Vitamin A',
                        _totalNutrients['vitaminA'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminA'] ??
                            900,
                        'mcg',
                        '🥕'),
                    _buildNutrientProgressCard(
                        'Vitamin C',
                        _totalNutrients['vitaminC'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminC'] ??
                            90,
                        'mg',
                        '🍊'),
                    _buildNutrientProgressCard(
                        'Vitamin D',
                        _totalNutrients['vitaminD'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminD'] ??
                            20,
                        'mcg',
                        '☀️'),
                    _buildNutrientProgressCard(
                        'Vitamin E',
                        _totalNutrients['vitaminE'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminE'] ??
                            15,
                        'mg',
                        '🌰'),
                    _buildNutrientProgressCard(
                        'Vitamin K',
                        _totalNutrients['vitaminK'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminK'] ??
                            120,
                        'mcg',
                        '🥬'),
                    _buildNutrientProgressCard(
                        'Vitamin B1',
                        _totalNutrients['vitaminB1'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB1'] ??
                            1.2,
                        'mg',
                        '🌾'),
                    _buildNutrientProgressCard(
                        'Vitamin B2',
                        _totalNutrients['vitaminB2'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB2'] ??
                            1.3,
                        'mg',
                        '🥛'),
                    _buildNutrientProgressCard(
                        'Vitamin B3',
                        _totalNutrients['vitaminB3'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB3'] ??
                            16,
                        'mg',
                        '🍖'),
                    _buildNutrientProgressCard(
                        'Vitamin B5',
                        _totalNutrients['vitaminB5'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB5'] ??
                            5,
                        'mg',
                        '🥚'),
                    _buildNutrientProgressCard(
                        'Vitamin B6',
                        _totalNutrients['vitaminB6'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB6'] ??
                            1.3,
                        'mg',
                        '🐟'),
                    _buildNutrientProgressCard(
                        'Vitamin B7',
                        _totalNutrients['vitaminB7'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB7'] ??
                            30,
                        'mcg',
                        '🥜'),
                    _buildNutrientProgressCard(
                        'Vitamin B9',
                        _totalNutrients['vitaminB9'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['vitaminB9'] ??
                            400,
                        'mcg',
                        '🥬'),
                    _buildNutrientProgressCard(
                        'Folate',
                        _totalNutrients['folate'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['folate'] ??
                            400,
                        'mcg',
                        '🥬'),
                    _buildNutrientProgressCard(
                        'Vitamin B12',
                        _totalNutrients['vitaminB12'] ?? 0.0,
                        widget.profile
                                .dailyNutrientRequirements['vitaminB12'] ??
                            2.4,
                        'mcg',
                        '💊'),
                  ]),
                ],
              ),
            ),

            // Minerals Progress Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  color: Color(0xFF0E2E20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.grain, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('MINERALS PROGRESS',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8F5E9))))
                  ]),
                  const SizedBox(height: 8),
                  ..._buildNutrientGrid([
                    _buildNutrientProgressCard(
                        'Sodium',
                        _totalNutrients['sodium'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['sodium'] ??
                            2300,
                        'mg',
                        '🧂'),
                    _buildNutrientProgressCard(
                        'Calcium',
                        _totalNutrients['calcium'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['calcium'] ??
                            1000,
                        'mg',
                        '🦴'),
                    _buildNutrientProgressCard(
                        'Iron',
                        _totalNutrients['iron'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['iron'] ?? 18,
                        'mg',
                        '⚡'),
                    _buildNutrientProgressCard(
                        'Potassium',
                        _totalNutrients['potassium'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['potassium'] ??
                            3500,
                        'mg',
                        '🍌'),
                    _buildNutrientProgressCard(
                        'Magnesium',
                        _totalNutrients['magnesium'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['magnesium'] ??
                            400,
                        'mg',
                        '✨'),
                    _buildNutrientProgressCard(
                        'Zinc',
                        _totalNutrients['zinc'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['zinc'] ?? 11,
                        'mg',
                        '🔧'),
                    _buildNutrientProgressCard(
                        'Phosphorus',
                        _totalNutrients['phosphorus'] ?? 0.0,
                        widget.profile
                                .dailyNutrientRequirements['phosphorus'] ??
                            700,
                        'mg',
                        '🦴'),
                    _buildNutrientProgressCard(
                        'Copper',
                        _totalNutrients['copper'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['copper'] ??
                            0.9,
                        'mg',
                        '🔧'),
                    _buildNutrientProgressCard(
                        'Manganese',
                        _totalNutrients['manganese'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['manganese'] ??
                            2.3,
                        'mg',
                        '⚡'),
                    _buildNutrientProgressCard(
                        'Selenium',
                        _totalNutrients['selenium'] ?? 0.0,
                        widget.profile.dailyNutrientRequirements['selenium'] ??
                            55,
                        'mcg',
                        '✨'),
                  ]),
                ],
              ),
            ),

            // Health Limits Monitoring Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Color(0xFF0E2E20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('HEALTH LIMITS MONITORING',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8F5E9))))
                  ]),
                  const SizedBox(height: 8),
                  Text('TRY TO KEEP THESE PERCENTAGES LOW',
                      style: TextStyle(fontSize: 14, color: Color(0xFFE8F5E9))),
                  const SizedBox(height: 16),
                  // Debug print to verify UI updates
                  if (kDebugMode)
                    Text(
                        'Debug: Added Sugar=${_totalNutrients['addedSugar']}, Vitamin D=${_totalNutrients['vitaminD']}, Omega-3=${_totalNutrients['omega3']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ..._buildNutrientGrid([
                    _buildNutrientProgressCard(
                        'Added Sugar',
                        _totalNutrients['addedSugar'] ?? 0.0,
                        _healthLimits['addedSugar'] ?? 30.0,
                        'g',
                        '🍰'),
                    _buildNutrientProgressCard(
                        'Trans Fat',
                        _totalNutrients['transFat'] ?? 0.0,
                        _healthLimits['transFat'] ?? 2.0,
                        'g',
                        '⚠️'),
                    _buildNutrientProgressCard(
                        'Saturated Fat',
                        _totalNutrients['saturatedFat'] ?? 0.0,
                        _healthLimits['saturatedFat'] ?? 20.0,
                        'g',
                        '🥓'),
                    _buildNutrientProgressCard(
                        'Refined Carbs',
                        _totalNutrients['refinedCarbs'] ?? 0.0,
                        _healthLimits['refinedCarbs'] ?? 50.0,
                        'g',
                        '🍞'),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print(
              '=== DEBUG: FAB pressed, current _showFoodForm: $_showFoodForm ===');
          setState(() => _showFoodForm = !_showFoodForm);
          print('=== DEBUG: After setState, _showFoodForm: $_showFoodForm ===');

          // Scroll to food form when it's shown
          if (_showFoodForm) {
            print(
                '=== DEBUG: Form is now shown, calling _scrollToFoodForm ===');
            _scrollToFoodForm();
          } else {
            print('=== DEBUG: Form is now hidden, no scrolling needed ===');
          }
        },
        backgroundColor: AppColors.primary,
        child: Icon(_showFoodForm ? Icons.close : Icons.add),
        tooltip: 'Add Custom Food',
      ),
    );
  }
}
