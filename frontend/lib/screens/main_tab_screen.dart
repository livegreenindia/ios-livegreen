import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';
import 'home_screen.dart';
import 'history_page.dart';
import 'camera_page.dart';

// DailyIntake class for food storage
class DailyIntake {
  final DateTime date;
  final Map<String, double> nutrients;
  final double totalCalories;
  final Map<String, double> dailyRequirements;
  final List<String> scannedFoods;

  DailyIntake({
    required this.date,
    required this.nutrients,
    required this.totalCalories,
    required this.dailyRequirements,
    required this.scannedFoods,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'nutrients': nutrients,
      'totalCalories': totalCalories,
      'dailyRequirements': dailyRequirements,
      'scannedFoods': scannedFoods,
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
          : [],
    );
  }
}

class MainTabScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final UserProfile profile;
  final Function(UserProfile)? onProfileUpdated;

  const MainTabScreen({Key? key, required this.cameras, required this.profile, this.onProfileUpdated}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _currentProfile;
  final String _apiKey = '';
  bool _isSaving = false; // Add flag to prevent duplicate saves
  
  // Method to add new food items from HomeScreen
  void addFoodToHistory(String nutritionInfo, String foodName) {
    print('MainTabScreen: addFoodToHistory called with $foodName');
    print('Nutrition info: ${nutritionInfo.substring(0, 100)}...');
    print('Saving food from HomeScreen to history...');
    
    // Save the food to history
    _saveFoodToHistory(nutritionInfo);
    
    // Switch to history tab to show the new entry
    _tabController.animateTo(2);
    // Refresh UI
    setState(() {});
  }

  // Method to clear all history data (for debugging duplicate entries)
  Future<void> _clearAllHistory() async {
    try {
      print('=== CLEARING ALL HISTORY ===');
      final prefs = await SharedPreferences.getInstance();
      
      // Clear the main history list
      await prefs.remove('dailyIntakeHistory');
      
      // Clear all individual daily entries
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('dailyIntake_')) {
          await prefs.remove(key);
        }
      }
      
      print('All history cleared');
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  // Method to save food analysis to history
  Future<void> _saveFoodToHistory(String nutritionInfo) async {
    // Prevent multiple simultaneous saves
    if (_isSaving) {
      print('Already saving, skipping duplicate save request');
      return;
    }
    
    _isSaving = true;
    
    try {
      print('=== SAVING FOOD TO HISTORY ===');
      print('Nutrition info: ${nutritionInfo.substring(0, 100)}...');
      
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      
      print('Today key: $todayKey');
      
      // Create unique ID for this food entry based on timestamp and content hash
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final contentHash = nutritionInfo.hashCode;
      final uniqueId = '${timestamp}_$contentHash';
      
      print('Generated unique ID: $uniqueId');
      
      // Get existing daily intake or create new one
      final existingIntakeJson = prefs.getString('dailyIntake_$todayKey');
      DailyIntake dailyIntake;
      
      if (existingIntakeJson != null) {
        print('Found existing intake for today');
        dailyIntake = DailyIntake.fromJson(Map<String, dynamic>.from(jsonDecode(existingIntakeJson)));
        
        // Check if this exact food entry already exists (to prevent duplicates)
        final nutritionHash = nutritionInfo.hashCode;
        print('=== DUPLICATE CHECK ===');
        print('New food hash: $nutritionHash');
        print('New food: ${nutritionInfo.substring(0, 100)}...');
        print('Existing foods count: ${dailyIntake.scannedFoods.length}');
        
        int duplicateCount = 0;
        final alreadyExists = dailyIntake.scannedFoods.any((food) {
          String existingFoodInfo;
          if (food.startsWith('ID:')) {
            // Extract nutrition info after the ID
            final parts = food.split('|');
            if (parts.length >= 2) {
              existingFoodInfo = parts.sublist(1).join('|');
            } else {
              existingFoodInfo = food;
            }
          } else {
            existingFoodInfo = food;
          }
          
          final existingHash = existingFoodInfo.hashCode;
          final isDuplicate = existingHash == nutritionHash;
          
          print('--- Checking existing food ---');
          print('Existing hash: $existingHash');
          print('Existing food: ${existingFoodInfo.substring(0, 100)}...');
          print('Is duplicate: $isDuplicate');
          
          if (isDuplicate) {
            duplicateCount++;
            print('*** DUPLICATE FOUND #$duplicateCount ***');
          }
          
          return isDuplicate;
        });
        
        print('Total duplicates found: $duplicateCount');
        
        if (alreadyExists) {
          print('Food entry already exists for today, skipping save');
          print('=== SAVING COMPLETE (DUPLICATE SKIPPED) ===');
          return;
        }
        
        // Add new food to scanned foods with unique ID
        dailyIntake.scannedFoods.add('ID:$uniqueId|$nutritionInfo');
        
        // Update nutrients by adding the new food's nutrients
        final newNutrients = _extractNutrientsFromInfo(nutritionInfo);
        newNutrients.forEach((key, value) {
          dailyIntake.nutrients[key] = (dailyIntake.nutrients[key] ?? 0) + value;
        });
        
        print('Updated existing intake with new food');
      } else {
        print('Creating new intake for today');
        // Create new daily intake with unique ID
        dailyIntake = DailyIntake(
          date: today,
          nutrients: _extractNutrientsFromInfo(nutritionInfo),
          scannedFoods: ['ID:$uniqueId|$nutritionInfo'],
          totalCalories: _extractCaloriesFromInfo(nutritionInfo),
          dailyRequirements: _currentProfile?.dailyNutrientRequirements ?? widget.profile.dailyNutrientRequirements,
        );
        print('Created new intake');
      }
      
      // Save the updated daily intake
      await prefs.setString('dailyIntake_$todayKey', json.encode(dailyIntake.toJson()));
      
      // Update history list - replace existing entry for today or add new one
      final historyJson = prefs.getStringList('dailyIntakeHistory') ?? [];
      
      print('=== UPDATING HISTORY LIST ===');
      print('Current history entries: ${historyJson.length}');
      
      // Create date key for today (ignoring time)
      final todayDateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      print('Looking for existing entries with date key: $todayDateKey');
      
      // Remove ALL existing entries for today (same date, any time)
      final originalLength = historyJson.length;
      historyJson.removeWhere((json) {
        try {
          final decoded = jsonDecode(json);
          if (decoded is Map<String, dynamic>) {
            final existingDate = DateTime.parse(decoded['date']);
            final existingDateKey = '${existingDate.year}-${existingDate.month.toString().padLeft(2, '0')}-${existingDate.day.toString().padLeft(2, '0')}';
            final shouldRemove = existingDateKey == todayDateKey;
            if (shouldRemove) {
              print('Removing existing entry for date: $existingDateKey');
            }
            return shouldRemove;
          }
        } catch (e) {
          print('Error parsing history entry: $e');
        }
        return false;
      });
      
      print('Removed ${originalLength - historyJson.length} entries for today');
      
      // Add the updated entry for today (only one entry per day)
      historyJson.add(json.encode(dailyIntake.toJson()));
      await prefs.setStringList('dailyIntakeHistory', historyJson);
      
      print('Added new entry for today');
      print('Final history entries: ${historyJson.length}');
      
      print('History now has ${historyJson.length} total entries');
      
      print('Food saved to history: ${_extractFoodName(nutritionInfo)}');
      print('=== SAVING COMPLETE ===');
    } catch (e) {
      print('Error saving food to history: $e');
    } finally {
      _isSaving = false;
    }
  }

  Map<String, double> _extractNutrientsFromInfo(String nutritionInfo) {
    final nutrients = <String, double>{};
    
    print('=== EXTRACTING NUTRIENTS FROM INFO ===');
    print('Full nutrition info: ${nutritionInfo.substring(0, 200)}...');
    
    // Macronutrients
    final caloriesMatch = RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal', caseSensitive: false).firstMatch(nutritionInfo);
    final proteinMatch = RegExp(r'PROTEIN:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final carbMatch = RegExp(r'CARBOHYDRATES:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final fatMatch = RegExp(r'FAT:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final fiberMatch = RegExp(r'FIBER:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final sodiumMatch = RegExp(r'SODIUM:\s*(\d+(?:\.\d+)?)\s*mg', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (caloriesMatch != null) {
      nutrients['calories'] = double.parse(caloriesMatch.group(1)!);
      print('Extracted calories: ${nutrients['calories']}');
    }
    if (proteinMatch != null) {
      nutrients['protein'] = double.parse(proteinMatch.group(1)!);
      print('Extracted protein: ${nutrients['protein']}');
    }
    if (carbMatch != null) {
      nutrients['carbohydrates'] = double.parse(carbMatch.group(1)!);
      print('Extracted carbohydrates: ${nutrients['carbohydrates']}');
    }
    if (fatMatch != null) {
      nutrients['fat'] = double.parse(fatMatch.group(1)!);
      print('Extracted fat: ${nutrients['fat']}');
    }
    if (fiberMatch != null) {
      nutrients['fiber'] = double.parse(fiberMatch.group(1)!);
      print('Extracted fiber: ${nutrients['fiber']}');
    }
    if (sodiumMatch != null) {
      nutrients['sodium'] = double.parse(sodiumMatch.group(1)!);
      print('Extracted sodium: ${nutrients['sodium']}');
    }
    
    // Fiber breakdown - NEW
    final totalFiberMatch = RegExp(r'TOTAL[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final solubleFiberMatch = RegExp(r'SOLUBLE[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final insolubleFiberMatch = RegExp(r'INSOLUBLE[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final prebioticFiberMatch = RegExp(r'PREBIOTIC[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (totalFiberMatch != null) {
      nutrients['totalFiber'] = double.parse(totalFiberMatch.group(1)!);
      print('✅ Extracted TOTAL FIBER: ${nutrients['totalFiber']}');
    }
    if (solubleFiberMatch != null) {
      nutrients['solubleFiber'] = double.parse(solubleFiberMatch.group(1)!);
      print('✅ Extracted SOLUBLE FIBER: ${nutrients['solubleFiber']}');
    }
    if (insolubleFiberMatch != null) {
      nutrients['insolubleFiber'] = double.parse(insolubleFiberMatch.group(1)!);
      print('✅ Extracted INSOLUBLE FIBER: ${nutrients['insolubleFiber']}');
    }
    if (prebioticFiberMatch != null) {
      nutrients['prebioticFiber'] = double.parse(prebioticFiberMatch.group(1)!);
      print('✅ Extracted PREBIOTIC FIBER: ${nutrients['prebioticFiber']}');
    }
    
    // Fat breakdown - NEW
    final monounsaturatedFatMatch = RegExp(r'MONOUNSATURATED[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final omega3Match = RegExp(r'OMEGA[-_]?3:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final omega6Match = RegExp(r'OMEGA[-_]?6:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (monounsaturatedFatMatch != null) {
      nutrients['monounsaturatedFat'] = double.parse(monounsaturatedFatMatch.group(1)!);
      print('✅ Extracted MONOUNSATURATED FAT: ${nutrients['monounsaturatedFat']}');
    }
    if (omega3Match != null) {
      nutrients['omega3'] = double.parse(omega3Match.group(1)!);
      print('✅ Extracted OMEGA-3: ${nutrients['omega3']}');
    }
    if (omega6Match != null) {
      nutrients['omega6'] = double.parse(omega6Match.group(1)!);
      print('✅ Extracted OMEGA-6: ${nutrients['omega6']}');
    }
    
    // Complete Vitamins - ENHANCED
    final vitaminAMatch = RegExp(r'VITAMIN[_\s]?A:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminCMatch = RegExp(r'VITAMIN[_\s]?C:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminDMatch = RegExp(r'VITAMIN[_\s]?D:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB12Match = RegExp(r'VITAMIN[_\s]?B12:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final folateMatch = RegExp(r'FOLATE:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminEMatch = RegExp(r'VITAMIN[_\s]?E:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminKMatch = RegExp(r'VITAMIN[_\s]?K:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB1Match = RegExp(r'VITAMIN[_\s]?B1:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB2Match = RegExp(r'VITAMIN[_\s]?B2:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB3Match = RegExp(r'VITAMIN[_\s]?B3:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB5Match = RegExp(r'VITAMIN[_\s]?B5:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB6Match = RegExp(r'VITAMIN[_\s]?B6:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB7Match = RegExp(r'VITAMIN[_\s]?B7:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final vitaminB9Match = RegExp(r'VITAMIN[_\s]?B9:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (vitaminAMatch != null) {
      nutrients['vitaminA'] = double.parse(vitaminAMatch.group(1)!);
      print('✅ Extracted VITAMIN A: ${nutrients['vitaminA']}');
    }
    if (vitaminCMatch != null) {
      nutrients['vitaminC'] = double.parse(vitaminCMatch.group(1)!);
      print('✅ Extracted VITAMIN C: ${nutrients['vitaminC']}');
    }
    if (vitaminDMatch != null) {
      nutrients['vitaminD'] = double.parse(vitaminDMatch.group(1)!);
      print('✅ Extracted VITAMIN D: ${nutrients['vitaminD']}');
    }
    if (vitaminB12Match != null) {
      nutrients['vitaminB12'] = double.parse(vitaminB12Match.group(1)!);
      print('✅ Extracted VITAMIN B12: ${nutrients['vitaminB12']}');
    }
    if (folateMatch != null) {
      nutrients['folate'] = double.parse(folateMatch.group(1)!);
      print('✅ Extracted FOLATE: ${nutrients['folate']}');
    }
    if (vitaminEMatch != null) {
      nutrients['vitaminE'] = double.parse(vitaminEMatch.group(1)!);
      print('✅ Extracted VITAMIN E: ${nutrients['vitaminE']}');
    }
    if (vitaminKMatch != null) {
      nutrients['vitaminK'] = double.parse(vitaminKMatch.group(1)!);
      print('✅ Extracted VITAMIN K: ${nutrients['vitaminK']}');
    }
    if (vitaminB1Match != null) {
      nutrients['vitaminB1'] = double.parse(vitaminB1Match.group(1)!);
      print('✅ Extracted VITAMIN B1: ${nutrients['vitaminB1']}');
    }
    if (vitaminB2Match != null) {
      nutrients['vitaminB2'] = double.parse(vitaminB2Match.group(1)!);
      print('✅ Extracted VITAMIN B2: ${nutrients['vitaminB2']}');
    }
    if (vitaminB3Match != null) {
      nutrients['vitaminB3'] = double.parse(vitaminB3Match.group(1)!);
      print('✅ Extracted VITAMIN B3: ${nutrients['vitaminB3']}');
    }
    if (vitaminB5Match != null) {
      nutrients['vitaminB5'] = double.parse(vitaminB5Match.group(1)!);
      print('✅ Extracted VITAMIN B5: ${nutrients['vitaminB5']}');
    }
    if (vitaminB6Match != null) {
      nutrients['vitaminB6'] = double.parse(vitaminB6Match.group(1)!);
      print('✅ Extracted VITAMIN B6: ${nutrients['vitaminB6']}');
    }
    if (vitaminB7Match != null) {
      nutrients['vitaminB7'] = double.parse(vitaminB7Match.group(1)!);
      print('✅ Extracted VITAMIN B7: ${nutrients['vitaminB7']}');
    }
    if (vitaminB9Match != null) {
      nutrients['vitaminB9'] = double.parse(vitaminB9Match.group(1)!);
      print('✅ Extracted VITAMIN B9: ${nutrients['vitaminB9']}');
    }
    
    // Complete Minerals - ENHANCED
    final ironMatch = RegExp(r'IRON:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final calciumMatch = RegExp(r'CALCIUM:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final potassiumMatch = RegExp(r'POTASSIUM:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final magnesiumMatch = RegExp(r'MAGNESIUM:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final zincMatch = RegExp(r'ZINC:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final phosphorusMatch = RegExp(r'PHOSPHORUS:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final copperMatch = RegExp(r'COPPER:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final manganeseMatch = RegExp(r'MANGANESE:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final seleniumMatch = RegExp(r'SELENIUM:\s*(\d+(?:\.\d+)?)\s*(?:mcg)?', caseSensitive: false).firstMatch(nutritionInfo);
    final cholesterolMatch = RegExp(r'CHOLESTEROL:\s*(\d+(?:\.\d+)?)\s*(?:mg)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (ironMatch != null) {
      nutrients['iron'] = double.parse(ironMatch.group(1)!);
      print('✅ Extracted IRON: ${nutrients['iron']}');
    }
    if (calciumMatch != null) {
      nutrients['calcium'] = double.parse(calciumMatch.group(1)!);
      print('✅ Extracted CALCIUM: ${nutrients['calcium']}');
    }
    if (potassiumMatch != null) {
      nutrients['potassium'] = double.parse(potassiumMatch.group(1)!);
      print('✅ Extracted POTASSIUM: ${nutrients['potassium']}');
    }
    if (magnesiumMatch != null) {
      nutrients['magnesium'] = double.parse(magnesiumMatch.group(1)!);
      print('✅ Extracted MAGNESIUM: ${nutrients['magnesium']}');
    }
    if (zincMatch != null) {
      nutrients['zinc'] = double.parse(zincMatch.group(1)!);
      print('✅ Extracted ZINC: ${nutrients['zinc']}');
    }
    if (phosphorusMatch != null) {
      nutrients['phosphorus'] = double.parse(phosphorusMatch.group(1)!);
      print('✅ Extracted PHOSPHORUS: ${nutrients['phosphorus']}');
    }
    if (copperMatch != null) {
      nutrients['copper'] = double.parse(copperMatch.group(1)!);
      print('✅ Extracted COPPER: ${nutrients['copper']}');
    }
    if (manganeseMatch != null) {
      nutrients['manganese'] = double.parse(manganeseMatch.group(1)!);
      print('✅ Extracted MANGANESE: ${nutrients['manganese']}');
    }
    if (seleniumMatch != null) {
      nutrients['selenium'] = double.parse(seleniumMatch.group(1)!);
      print('✅ Extracted SELENIUM: ${nutrients['selenium']}');
    }
    if (cholesterolMatch != null) {
      nutrients['cholesterol'] = double.parse(cholesterolMatch.group(1)!);
      print('✅ Extracted CHOLESTEROL: ${nutrients['cholesterol']}');
    }
    
    // Items to limit - ENHANCED
    final addedSugarMatch = RegExp(r'ADDED[_\s]SUGAR:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final transFatMatch = RegExp(r'TRANS[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final saturatedFatMatch = RegExp(r'SATURATED[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final refinedCarbsMatch = RegExp(r'REFINED[_\s]CARBS:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (addedSugarMatch != null) {
      nutrients['addedSugar'] = double.parse(addedSugarMatch.group(1)!);
      print('✅ Extracted ADDED SUGAR: ${nutrients['addedSugar']}');
    }
    if (transFatMatch != null) {
      nutrients['transFat'] = double.parse(transFatMatch.group(1)!);
      print('✅ Extracted TRANS FAT: ${nutrients['transFat']}');
    }
    if (saturatedFatMatch != null) {
      nutrients['saturatedFat'] = double.parse(saturatedFatMatch.group(1)!);
      print('✅ Extracted SATURATED FAT: ${nutrients['saturatedFat']}');
    }
    if (refinedCarbsMatch != null) {
      nutrients['refinedCarbs'] = double.parse(refinedCarbsMatch.group(1)!);
      print('✅ Extracted REFINED CARBS: ${nutrients['refinedCarbs']}');
    }
    
    print('Final extracted nutrients: ${nutrients}');
    print('=== NUTRIENT EXTRACTION COMPLETE ===');
    
    return nutrients;
  }

  double _extractCaloriesFromInfo(String nutritionInfo) {
    final caloriesMatch = RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal').firstMatch(nutritionInfo);
    return caloriesMatch != null ? double.parse(caloriesMatch.group(1)!) : 0.0;
  }

  String _extractFoodName(String nutritionInfo) {
    final foodNameMatch = RegExp(r'FOOD_NAME:\s*(.+?)(?:\n|$)').firstMatch(nutritionInfo);
    if (foodNameMatch != null) {
      return foodNameMatch.group(1)!.trim();
    }
    return 'Food Item';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentProfile = widget.profile;
    
    // Add listener to refresh history when switching to history tab
    _tabController.addListener(() {
      if (_tabController.index == 2) {
        // When switching to history tab, trigger a rebuild to refresh data
        setState(() {});
      }
    });
  }

  void _updateProfile(UserProfile updatedProfile) {
    setState(() {
      _currentProfile = updatedProfile;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          HomeScreen(
            cameras: widget.cameras, 
            profile: _currentProfile ?? widget.profile,
            onFoodAdded: (nutritionInfo, foodName) {
              addFoodToHistory(nutritionInfo, foodName);
            },
            onProfileUpdated: (updatedProfile) {
              print('=== DEBUG: MainTabScreen onProfileUpdated called ===');
              print('=== DEBUG: New weight: ${updatedProfile.weight} ===');
              setState(() {
                _currentProfile = updatedProfile;
                print('=== DEBUG: _currentProfile updated in MainTabScreen ===');
              });
              // Update main app profile
              if (widget.onProfileUpdated != null) {
                widget.onProfileUpdated!(updatedProfile);
              }
            },
            onClearHistory: () {
              _clearAllHistory().then((_) {
                setState(() {});
                _tabController.animateTo(2); // Go to history tab to see cleared state
              });
            },
          ),
          CameraPage(
            cameras: widget.cameras,
            apiKey: _apiKey,
            userProfile: _currentProfile ?? widget.profile,
            onFoodAnalyzed: (nutritionInfo) async {
              print('=== FOOD ANALYZED CALLBACK TRIGGERED ===');
              print('Nutrition info received: ${nutritionInfo.substring(0, 100)}...');
              
              // Save the nutrition data to storage
              await _saveFoodToHistory(nutritionInfo);
              
              // Refresh the history page when new food is added
              setState(() {});
              
              print('=== FOOD ANALYZED CALLBACK COMPLETE ===');
            },
            onClose: () {
              // Switch to home tab when close is pressed
              _tabController.animateTo(0);
            },
          ),
          HistoryPage(
            profile: _currentProfile ?? widget.profile,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              icon: Icon(Icons.home, size: 24),
              text: 'Home',
            ),
            Tab(
              icon: Icon(Icons.camera_alt, size: 24),
              text: 'Scan',
            ),
            Tab(
              icon: Icon(Icons.history, size: 24),
              text: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
