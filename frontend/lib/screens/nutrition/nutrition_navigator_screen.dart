import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/user_profile.dart';
import '../home_screen.dart' hide DailyIntake;
import '../history_page.dart' hide DailyIntake;
import '../camera_page.dart';
import '../profile_setup_page.dart';
import '../main_tab_screen.dart' show DailyIntake;

class NutritionNavigatorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final UserProfile profile;

  const NutritionNavigatorScreen({
    Key? key,
    required this.cameras,
    required this.profile,
  }) : super(key: key);

  @override
  State<NutritionNavigatorScreen> createState() =>
      _NutritionNavigatorScreenState();
}

class _NutritionNavigatorScreenState extends State<NutritionNavigatorScreen> {
  int _currentIndex = 1; // Start with Home tab
  UserProfile? _profile;
  final GlobalKey<State> _historyPageKey = GlobalKey<State>();

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _updateProfile() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSetupPage(
          cameras: widget.cameras,
          existingProfile: _profile,
          onProfileSaved: (updatedProfile) async {
            print(
                'NutritionNavigatorScreen: Profile updated from ${_profile?.weight}kg to ${updatedProfile.weight}kg');
            print(
                'Health conditions updated: ${_profile?.healthConditions} -> ${updatedProfile.healthConditions}');

            // Save updated profile
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                'user_profile', json.encode(updatedProfile.toJson()));

            setState(() {
              _profile = updatedProfile;
            });

            // Navigate back with updated profile
            Navigator.of(context).pop();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Profile updated successfully! Nutrient requirements recalculated.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isSaving = false;

  void _onFoodAnalyzed(String nutritionInfo) async {
    print('NutritionNavigatorScreen: Food analyzed callback received');

    // Save the food to history
    await _saveFoodToHistory(nutritionInfo);

    // Switch to history tab to show the updated data
    setState(() {
      _currentIndex = 2; // History tab
    });

    // Refresh history page if it has a refresh method
    if (_historyPageKey.currentState != null) {
      final historyState = _historyPageKey.currentState;
      if (historyState is State) {
        // Call refresh if the state has that method
        try {
          (historyState as dynamic).refreshData();
        } catch (e) {
          print('Could not call refreshData: $e');
        }
      }
    }
  }

  // Same logic as main_tab_screen to save properly
  Future<void> _saveFoodToHistory(String nutritionInfo) async {
    if (_isSaving) return;
    _isSaving = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final contentHash = nutritionInfo.hashCode;
      final uniqueId = '${timestamp}_$contentHash';
      
      final existingIntakeJson = prefs.getString('dailyIntake_$todayKey');
      DailyIntake dailyIntake;
      
      if (existingIntakeJson != null) {
        dailyIntake = DailyIntake.fromJson(Map<String, dynamic>.from(jsonDecode(existingIntakeJson)));
        final nutritionHash = nutritionInfo.hashCode;
        
        final alreadyExists = dailyIntake.scannedFoods.any((food) {
          String existingFoodInfo;
          if (food.startsWith('ID:')) {
            final parts = food.split('|');
            existingFoodInfo = parts.length >= 2 ? parts.sublist(1).join('|') : food;
          } else {
            existingFoodInfo = food;
          }
          return existingFoodInfo.hashCode == nutritionHash;
        });
        
        if (alreadyExists) return;
        
        dailyIntake.scannedFoods.add('ID:$uniqueId|$nutritionInfo');
        
        final newNutrients = _extractNutrientsFromInfo(nutritionInfo);
        newNutrients.forEach((key, value) {
          dailyIntake.nutrients[key] = (dailyIntake.nutrients[key] ?? 0) + value;
        });
      } else {
        dailyIntake = DailyIntake(
          date: today,
          nutrients: _extractNutrientsFromInfo(nutritionInfo),
          scannedFoods: ['ID:$uniqueId|$nutritionInfo'],
          totalCalories: _extractCaloriesFromInfo(nutritionInfo),
          dailyRequirements: _profile?.dailyNutrientRequirements ?? {},
        );
      }
      
      await prefs.setString('dailyIntake_$todayKey', json.encode(dailyIntake.toJson()));
      
      final historyJson = prefs.getStringList('dailyIntakeHistory') ?? [];
      final todayDateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      historyJson.removeWhere((json) {
        try {
          final decoded = jsonDecode(json);
          if (decoded is Map<String, dynamic>) {
            final existingDate = DateTime.parse(decoded['date']);
            final existingDateKey = '${existingDate.year}-${existingDate.month.toString().padLeft(2, '0')}-${existingDate.day.toString().padLeft(2, '0')}';
            return existingDateKey == todayDateKey;
          }
        } catch (_) {}
        return false;
      });
      
      historyJson.add(json.encode(dailyIntake.toJson()));
      await prefs.setStringList('dailyIntakeHistory', historyJson);
      
    } catch (e) {
      print('Error saving food to history: $e');
    } finally {
      _isSaving = false;
    }
  }

  Map<String, double> _extractNutrientsFromInfo(String nutritionInfo) {
    final nutrients = <String, double>{};
    
    final caloriesMatch = RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal', caseSensitive: false).firstMatch(nutritionInfo);
    final proteinMatch = RegExp(r'PROTEIN:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final carbMatch = RegExp(r'CARBOHYDRATES:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final fatMatch = RegExp(r'FAT:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final fiberMatch = RegExp(r'FIBER:\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false).firstMatch(nutritionInfo);
    final sodiumMatch = RegExp(r'SODIUM:\s*(\d+(?:\.\d+)?)\s*mg', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (caloriesMatch != null) nutrients['calories'] = double.parse(caloriesMatch.group(1)!);
    if (proteinMatch != null) nutrients['protein'] = double.parse(proteinMatch.group(1)!);
    if (carbMatch != null) nutrients['carbohydrates'] = double.parse(carbMatch.group(1)!);
    if (fatMatch != null) nutrients['fat'] = double.parse(fatMatch.group(1)!);
    if (fiberMatch != null) nutrients['fiber'] = double.parse(fiberMatch.group(1)!);
    if (sodiumMatch != null) nutrients['sodium'] = double.parse(sodiumMatch.group(1)!);
    
    // Fiber breakdown
    final totalFiberMatch = RegExp(r'TOTAL[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final solubleFiberMatch = RegExp(r'SOLUBLE[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final insolubleFiberMatch = RegExp(r'INSOLUBLE[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final prebioticFiberMatch = RegExp(r'PREBIOTIC[_\s]FIBER:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (totalFiberMatch != null) nutrients['totalFiber'] = double.parse(totalFiberMatch.group(1)!);
    if (solubleFiberMatch != null) nutrients['solubleFiber'] = double.parse(solubleFiberMatch.group(1)!);
    if (insolubleFiberMatch != null) nutrients['insolubleFiber'] = double.parse(insolubleFiberMatch.group(1)!);
    if (prebioticFiberMatch != null) nutrients['prebioticFiber'] = double.parse(prebioticFiberMatch.group(1)!);
    
    // Fat breakdown
    final monounsaturatedFatMatch = RegExp(r'MONOUNSATURATED[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final omega3Match = RegExp(r'OMEGA[-_]?3:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final omega6Match = RegExp(r'OMEGA[-_]?6:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (monounsaturatedFatMatch != null) nutrients['monounsaturatedFat'] = double.parse(monounsaturatedFatMatch.group(1)!);
    if (omega3Match != null) nutrients['omega3'] = double.parse(omega3Match.group(1)!);
    if (omega6Match != null) nutrients['omega6'] = double.parse(omega6Match.group(1)!);
    
    // Complete Vitamins
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
    
    if (vitaminAMatch != null) nutrients['vitaminA'] = double.parse(vitaminAMatch.group(1)!);
    if (vitaminCMatch != null) nutrients['vitaminC'] = double.parse(vitaminCMatch.group(1)!);
    if (vitaminDMatch != null) nutrients['vitaminD'] = double.parse(vitaminDMatch.group(1)!);
    if (vitaminB12Match != null) nutrients['vitaminB12'] = double.parse(vitaminB12Match.group(1)!);
    if (folateMatch != null) nutrients['folate'] = double.parse(folateMatch.group(1)!);
    if (vitaminEMatch != null) nutrients['vitaminE'] = double.parse(vitaminEMatch.group(1)!);
    if (vitaminKMatch != null) nutrients['vitaminK'] = double.parse(vitaminKMatch.group(1)!);
    if (vitaminB1Match != null) nutrients['vitaminB1'] = double.parse(vitaminB1Match.group(1)!);
    if (vitaminB2Match != null) nutrients['vitaminB2'] = double.parse(vitaminB2Match.group(1)!);
    if (vitaminB3Match != null) nutrients['vitaminB3'] = double.parse(vitaminB3Match.group(1)!);
    if (vitaminB5Match != null) nutrients['vitaminB5'] = double.parse(vitaminB5Match.group(1)!);
    if (vitaminB6Match != null) nutrients['vitaminB6'] = double.parse(vitaminB6Match.group(1)!);
    if (vitaminB7Match != null) nutrients['vitaminB7'] = double.parse(vitaminB7Match.group(1)!);
    if (vitaminB9Match != null) nutrients['vitaminB9'] = double.parse(vitaminB9Match.group(1)!);
    
    // Complete Minerals
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
    
    if (ironMatch != null) nutrients['iron'] = double.parse(ironMatch.group(1)!);
    if (calciumMatch != null) nutrients['calcium'] = double.parse(calciumMatch.group(1)!);
    if (potassiumMatch != null) nutrients['potassium'] = double.parse(potassiumMatch.group(1)!);
    if (magnesiumMatch != null) nutrients['magnesium'] = double.parse(magnesiumMatch.group(1)!);
    if (zincMatch != null) nutrients['zinc'] = double.parse(zincMatch.group(1)!);
    if (phosphorusMatch != null) nutrients['phosphorus'] = double.parse(phosphorusMatch.group(1)!);
    if (copperMatch != null) nutrients['copper'] = double.parse(copperMatch.group(1)!);
    if (manganeseMatch != null) nutrients['manganese'] = double.parse(manganeseMatch.group(1)!);
    if (seleniumMatch != null) nutrients['selenium'] = double.parse(seleniumMatch.group(1)!);
    if (cholesterolMatch != null) nutrients['cholesterol'] = double.parse(cholesterolMatch.group(1)!);
    
    // Items to limit
    final addedSugarMatch = RegExp(r'ADDED[_\s]SUGAR:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final transFatMatch = RegExp(r'TRANS[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final saturatedFatMatch = RegExp(r'SATURATED[_\s]FAT:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    final refinedCarbsMatch = RegExp(r'REFINED[_\s]CARBS:\s*(\d+(?:\.\d+)?)\s*(?:g)?', caseSensitive: false).firstMatch(nutritionInfo);
    
    if (addedSugarMatch != null) nutrients['addedSugar'] = double.parse(addedSugarMatch.group(1)!);
    if (transFatMatch != null) nutrients['transFat'] = double.parse(transFatMatch.group(1)!);
    if (saturatedFatMatch != null) nutrients['saturatedFat'] = double.parse(saturatedFatMatch.group(1)!);
    if (refinedCarbsMatch != null) nutrients['refinedCarbs'] = double.parse(refinedCarbsMatch.group(1)!);
    
    return nutrients;
  }

  double _extractCaloriesFromInfo(String nutritionInfo) {
    final caloriesMatch = RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal').firstMatch(nutritionInfo);
    return caloriesMatch != null ? double.parse(caloriesMatch.group(1)!) : 0.0;
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0: // Camera
        return CameraPage(
          cameras: widget.cameras,
          // apiKey: 'AIzaSyCEU91Yy27b0VqBw95THdGpVlm-Oqu6eT0',
          apiKey: 'AIzaSyA25iyorUrEJUHKMMe4yyifwCHX-x2PiaI',
          userProfile: _profile,
          onFoodAnalyzed: _onFoodAnalyzed,
          onClose: () {
            // Switch to Home tab when camera is closed
            setState(() {
              _currentIndex = 1;
            });
          },
        );
      case 1: // Home
        return HomeScreen(
          cameras: widget.cameras,
          profile: _profile!,
          onProfileUpdated: (updatedProfile) async {
            // Save updated profile and refresh state
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                'user_profile', json.encode(updatedProfile.toJson()));
            setState(() {
              _profile = updatedProfile;
            });
          },
        );
      case 2: // History
        return HistoryPage(
          key: _historyPageKey,
          profile: _profile!,
          cameras: widget.cameras,
          onRefresh: () {
            // Refresh callback if needed
            setState(() {});
          },
        );
      default:
        return HomeScreen(
          cameras: widget.cameras,
          profile: _profile!,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
