import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import '../models/user_profile.dart';
import 'home_screen.dart';
import 'camera_page.dart';

class HistoryPage extends StatefulWidget {
  final UserProfile profile;
  final List<CameraDescription>? cameras;
  final VoidCallback? onRefresh;

  const HistoryPage(
      {Key? key, required this.profile, this.cameras, this.onRefresh})
      : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedTab = 'INSIGHTS REPORT';
  String _selectedPeriod = 'DAY';

  // Custom Project Dark Green Palette
  final Color darkBg = const Color(0xFF0A1A12);
  final Color cardEmerald = const Color(0xFF0E2E20);
  final Color accentGreen = const Color(0xFF1B5E20);
  final Color lightMint = const Color(0xFFE8F5E9);
  final Color secondaryGreen = const Color(0xFF2E7D32);
  final Color headerGreen = const Color(0xFF059669);

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  // Data storage
  List<DailyIntake> _dailyHistory = [];
  Map<String, Map<String, double>> _weeklyAverages = {};
  Map<String, Map<String, double>> _monthlyAverages = {};
  Map<String, Map<String, double>> _yearlyAverages = {};

  // Date selection
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  // Method to refresh data from outside
  void refreshData() {
    print('HistoryPage: refreshData called');
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    try {
      print('=== LOADING HISTORY DATA ===');
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('dailyIntakeHistory') ?? [];

      print('Found ${historyJson.length} history entries');

      setState(() {
        try {
          // Group entries by date (ignoring time) to combine same-day entries
          final Map<String, DailyIntake> groupedByDate = {};

          print('=== PROCESSING HISTORY ENTRIES ===');
          print('Total raw entries: ${historyJson.length}');

          for (final json in historyJson) {
            if (json.isEmpty) continue;

            try {
              final decoded = jsonDecode(json);
              if (decoded is Map<String, dynamic>) {
                final intake = DailyIntake.fromJson(decoded);
                final dateKey =
                    '${intake.date.year}-${intake.date.month.toString().padLeft(2, '0')}-${intake.date.day.toString().padLeft(2, '0')}';

                print('--- Processing entry ---');
                print('Date: $dateKey');
                print(
                    'Time: ${intake.date.hour}:${intake.date.minute}:${intake.date.second}');
                print('Foods: ${intake.scannedFoods.length}');
                print('Nutrients: ${intake.nutrients}');

                // Extract actual nutrition info from foods with IDs
                final processedFoods = <String>[];
                for (final food in intake.scannedFoods) {
                  if (food.startsWith('ID:')) {
                    // Extract nutrition info after the ID
                    final parts = food.split('|');
                    if (parts.length >= 2) {
                      processedFoods.add(parts.sublist(1).join('|'));
                    }
                  } else {
                    processedFoods.add(food);
                  }
                }

                // Create new intake with processed foods
                final processedIntake = DailyIntake(
                  date: intake.date,
                  nutrients: intake.nutrients,
                  scannedFoods: processedFoods,
                  totalCalories: intake.totalCalories,
                  dailyRequirements: intake.dailyRequirements,
                );

                if (groupedByDate.containsKey(dateKey)) {
                  // Combine with existing entry for this date
                  final existing = groupedByDate[dateKey]!;

                  print('Combining with existing entry for $dateKey');
                  print('Existing foods: ${existing.scannedFoods.length}');

                  // Add scanned foods
                  existing.scannedFoods.addAll(processedIntake.scannedFoods);

                  // Add nutrients
                  processedIntake.nutrients.forEach((key, value) {
                    existing.nutrients[key] =
                        (existing.nutrients[key] ?? 0) + value;
                  });

                  print(
                      'After combination - Total foods: ${existing.scannedFoods.length}');
                  print('After combination - Nutrients: ${existing.nutrients}');
                } else {
                  // Add new entry for this date
                  groupedByDate[dateKey] = processedIntake;
                  print('Added new entry for $dateKey');
                }
              }
            } catch (e) {
              print('Error parsing intake: $e');
            }
          }

          // Convert back to list and sort by date
          _dailyHistory = groupedByDate.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          print('Final daily history has ${_dailyHistory.length} unique days');

          // Print final grouped data
          for (final entry in _dailyHistory) {
            print(
                'Final entry: ${entry.date.year}-${entry.date.month}-${entry.date.day} - ${entry.scannedFoods.length} foods, ${entry.nutrients['calories'] ?? 0} calories');
          }
        } catch (e) {
          print('Error loading history: $e');
          _dailyHistory = [];
        }
        _calculateAverages();
      });
      print('=== LOADING COMPLETE ===');
    } catch (e) {
      // If SharedPreferences fails, generate sample data
      print('SharedPreferences failed: $e');
      _generateSampleData();
    }
  }

  void _generateSampleData() {
    // Generate sample data for demonstration
    final sampleData = <DailyIntake>[];
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final random = DateTime.now().millisecondsSinceEpoch + i;

      sampleData.add(DailyIntake(
        date: date,
        nutrients: {
          'calories': 1500 + (random % 800),
          'protein': 40 + (random % 40),
          'carbohydrates': 180 + (random % 120),
          'fat': 45 + (random % 35),
          'fiber': 15 + (random % 20),
          'sugar': 30 + (random % 40),
          'sodium': 1500 + (random % 2000),
          'iron': 8 + (random % 10),
          'calcium': 800 + (random % 400),
          'vitamin_c': 60 + (random % 80),
        },
        totalCalories: 1500 + (random % 800),
        dailyRequirements: widget.profile.dailyNutrientRequirements,
        scannedFoods: [
          'FOOD_NAME: Sample Food ${i % 5 + 1}\nCALORIES: ${(200 + (random % 300)).toStringAsFixed(1)} kcal\nPROTEIN: ${(10 + (random % 20)).toStringAsFixed(1)} g\nCARBOHYDRATES: ${(30 + (random % 40)).toStringAsFixed(1)} g\nFAT: ${(5 + (random % 15)).toStringAsFixed(1)} g\nFIBER: ${(2 + (random % 8)).toStringAsFixed(1)} g'
        ],
      ));
    }

    setState(() {
      _dailyHistory = sampleData;
      _calculateAverages();
    });
  }

  void _calculateAverages() {
    if (_dailyHistory.isEmpty) return;

    print('=== CALCULATING AVERAGES ===');
    print('Daily history has ${_dailyHistory.length} entries');

    // Weekly averages
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
    final weekData = _dailyHistory
        .where((intake) =>
            intake.date.isAfter(weekStart.subtract(const Duration(days: 1))))
        .toList();

    if (weekData.isNotEmpty) {
      final weekAvg = _calculateAverageNutrients(weekData);
      _weeklyAverages[weekKey] = weekAvg;
      print(
          'Weekly averages calculated for ${weekData.length} days with key: $weekKey');
    } else {
      _weeklyAverages[weekKey] = {};
      print('No weekly data found for key: $weekKey');
    }

    // Monthly averages
    final Map<String, List<DailyIntake>> monthlyGroups = {};
    for (final intake in _dailyHistory) {
      final monthKey = '${intake.date.year}-${intake.date.month}';
      monthlyGroups.putIfAbsent(monthKey, () => []).add(intake);
    }

    _monthlyAverages = {};
    for (final monthKey in monthlyGroups.keys) {
      final monthData = monthlyGroups[monthKey]!;
      if (monthData.isNotEmpty) {
        _monthlyAverages[monthKey] = _calculateAverageNutrients(monthData);
        print('Monthly averages for $monthKey: ${monthData.length} days');
      }
    }

    // Yearly averages
    final Map<String, List<DailyIntake>> yearlyGroups = {};
    for (final intake in _dailyHistory) {
      final yearKey = '${intake.date.year}';
      yearlyGroups.putIfAbsent(yearKey, () => []).add(intake);
    }

    _yearlyAverages = {};
    for (final yearKey in yearlyGroups.keys) {
      final yearData = yearlyGroups[yearKey]!;
      if (yearData.isNotEmpty) {
        _yearlyAverages[yearKey] = _calculateAverageNutrients(yearData);
        print('Yearly averages for $yearKey: ${yearData.length} days');
      }
    }

    print('=== AVERAGES CALCULATION COMPLETE ===');
  }

  Map<String, double> _calculateAverageNutrients(List<DailyIntake> data) {
    final nutrients = <String, double>{};

    // Get all unique nutrient keys from all data entries
    final Set<String> allNutrientKeys = {};
    for (final intake in data) {
      allNutrientKeys.addAll(intake.nutrients.keys);
    }

    // Calculate average for each nutrient
    for (final key in allNutrientKeys) {
      final total =
          data.map((d) => d.nutrients[key] ?? 0).reduce((a, b) => a + b);
      nutrients[key] = total / data.length;
    }

    print(
        'Calculated averages for ${nutrients.length} nutrients: ${nutrients}');
    return nutrients;
  }

  Map<String, double> _getCurrentPeriodData() {
    switch (_selectedPeriod) {
      case 'DAY':
        final dayData = _dailyHistory
            .where((intake) =>
                intake.date.year == _selectedDate.year &&
                intake.date.month == _selectedDate.month &&
                intake.date.day == _selectedDate.day)
            .toList();
        return dayData.isNotEmpty ? dayData.first.nutrients : {};

      case 'WEEK':
        final weekStart =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
        return _weeklyAverages[weekKey] ?? {};

      case 'MONTH':
        final monthKey = '${_selectedYear}-${_selectedMonth}';
        return _monthlyAverages[monthKey] ?? {};

      case 'YEAR':
        final yearKey = '${_selectedYear}';
        return _yearlyAverages[yearKey] ?? {};

      default:
        return {};
    }
  }

  double _calculatePeriodScore() {
    final data = _getCurrentPeriodData();
    if (data.isEmpty) return 0.0;

    final requirements = widget.profile.dailyNutrientRequirements;

    double totalScore = 0;
    int count = 0;

    requirements.forEach((nutrient, target) {
      final consumed = data[nutrient] ?? 0;
      final percentage = (consumed / target * 100).clamp(0, 150);
      totalScore +=
          percentage > 100 ? 100 - (percentage - 100) * 0.5 : percentage;
      count++;
    });

    return count > 0 ? totalScore / count : 0;
  }

  String _getGrade() {
    final score = _calculatePeriodScore();
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          title: const Text('Nutrition History'),
          backgroundColor: cardEmerald,
          foregroundColor: lightMint,
        ),
        body: Column(
          children: [
            // Header
            Container(
              color: cardEmerald,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('🥗', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NutriTrack AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'KARNATAKA EDITION',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Intelligence',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: lightMint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ADVANCED HEALTH ANALYTICS',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _buildTab('INSIGHTS REPORT')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTab('LOG ARCHIVE')),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_selectedTab == 'INSIGHTS REPORT')
                      _buildInsightsReport()
                    else
                      _buildLogArchive(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error in build: $e');
      return Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: cardEmerald,
        ),
        body: Center(
          child: Text('Error: $e', style: TextStyle(color: lightMint)),
        ),
      );
    }
  }

  Widget _buildTab(String label) {
    final isSelected = _selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? secondaryGreen : cardEmerald,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: accentGreen),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsReport() {
    final periodData = _getCurrentPeriodData();
    final score = _calculatePeriodScore();
    final grade = _getGrade();
    final daysCount = _getDaysInPeriod();

    return Column(
      children: [
        // Period Selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardEmerald,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentGreen),
          ),
          child: Row(
            children: [
              _buildPeriodButton('DAY'),
              _buildPeriodButton('WEEK'),
              _buildPeriodButton('MONTH'),
              _buildPeriodButton('YEAR'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Period Score Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardEmerald,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentGreen),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PERIOD SCORE: ${score.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analysis based on $daysCount days of activity.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: accentGreen, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: darkBg.withOpacity(0.5),
                ),
                child: Column(
                  children: [
                    const Text(
                      'GRADE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSection('MACRO PERFORMANCE', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _buildNutrientGrid([
                _buildNutrientItem(
                    'Calories',
                    periodData['calories'] ?? 0,
                    widget.profile.dailyNutrientRequirements['calories'] ??
                        2000,
                    'kcal'),
                _buildNutrientItem(
                    'Protein',
                    periodData['protein'] ?? 0,
                    widget.profile.dailyNutrientRequirements['protein'] ?? 50,
                    'g'),
                _buildNutrientItem(
                    'Carbs',
                    periodData['carbohydrates'] ?? 0,
                    widget.profile.dailyNutrientRequirements['carbohydrates'] ??
                        300,
                    'g'),
                _buildNutrientItem('Fat', periodData['fat'] ?? 0,
                    widget.profile.dailyNutrientRequirements['fat'] ?? 65, 'g'),
                _buildNutrientItem(
                    'Total Fiber',
                    periodData['fiber'] ?? 0,
                    widget.profile.dailyNutrientRequirements['fiber'] ?? 25,
                    'g'),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        _buildSection('FIBER BREAKDOWN', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _buildNutrientGrid([
                _buildNutrientItem(
                    'Total Fiber',
                    periodData['totalFiber'] ?? 0,
                    (widget.profile.dailyNutrientRequirements['fiber'] ?? 25),
                    'g'),
                _buildNutrientItem(
                    'Soluble Fiber',
                    periodData['solubleFiber'] ?? 0,
                    (widget.profile.dailyNutrientRequirements['fiber'] ?? 25) *
                        0.4,
                    'g'),
                _buildNutrientItem(
                    'Insoluble Fiber',
                    periodData['insolubleFiber'] ?? 0,
                    (widget.profile.dailyNutrientRequirements['fiber'] ?? 25) *
                        0.6,
                    'g'),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        _buildSection('ITEMS TO LIMIT PERFORMANCE', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _buildNutrientGrid([
                _buildNutrientItem(
                    'Added Sugar', periodData['addedSugar'] ?? 0, 50, 'g'),
                _buildNutrientItem(
                    'Trans Fat', periodData['transFat'] ?? 0, 2, 'g'),
                _buildNutrientItem(
                    'Saturated Fat', periodData['saturatedFat'] ?? 0, 20, 'g'),
                _buildNutrientItem(
                    'Refined Carbs', periodData['refinedCarbs'] ?? 0, 130, 'g'),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        _buildSection('DETAILED FAT BREAKDOWN', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _buildNutrientGrid([
                _buildNutrientItem(
                    'Mono Fat',
                    periodData['monounsaturatedFat'] ?? 0,
                    (widget.profile.dailyNutrientRequirements['fat'] ?? 70) *
                        0.4,
                    'g'),
                _buildNutrientItem(
                    'Omega-3', periodData['omega3'] ?? 0, 2.0, 'g'),
                _buildNutrientItem(
                    'Omega-6', periodData['omega6'] ?? 0, 10.0, 'g'),
                _buildNutrientItem(
                    'Saturated Fat',
                    periodData['saturatedFat'] ?? 0,
                    (widget.profile.dailyNutrientRequirements['fat'] ?? 70) *
                        0.3,
                    'g'),
                _buildNutrientItem(
                    'Trans Fat', periodData['transFat'] ?? 0, 2.0, 'g'),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        _buildSection('VITAMINS & MINERALS', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _buildNutrientGrid([
                _buildNutrientItem(
                    'Vit A', periodData['vitaminA'] ?? 0, 900, 'mcg'),
                _buildNutrientItem(
                    'Vit C', periodData['vitaminC'] ?? 0, 90, 'mg'),
                _buildNutrientItem(
                    'Vit D', periodData['vitaminD'] ?? 0, 20, 'mcg'),
                _buildNutrientItem(
                    'Vit E', periodData['vitaminE'] ?? 0, 15, 'mg'),
                _buildNutrientItem(
                    'Vit K', periodData['vitaminK'] ?? 0, 120, 'mcg'),
                _buildNutrientItem(
                    'Vit B12', periodData['vitaminB12'] ?? 0, 2.4, 'mcg'),
                _buildNutrientItem(
                    'Sodium', periodData['sodium'] ?? 0, 2300, 'mg'),
                _buildNutrientItem(
                    'Calcium', periodData['calcium'] ?? 0, 1000, 'mg'),
                _buildNutrientItem('Iron', periodData['iron'] ?? 0, 18, 'mg'),
                _buildNutrientItem('Zinc', periodData['zinc'] ?? 0, 11, 'mg'),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLogArchive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: lightMint,
            ),
          ),
        ),
        if (_dailyHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    'No food history yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: lightMint.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dailyHistory.length > 10 ? 10 : _dailyHistory.length,
            itemBuilder: (context, index) {
              if (index < _dailyHistory.length) {
                return _buildLogItem(_dailyHistory[index]);
              }
              return const SizedBox.shrink();
            },
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLogItem(DailyIntake intake) {
    final score = _calculateDayScore(intake);
    final mealCount = intake.scannedFoods.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardEmerald,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${intake.date.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${intake.date.month >= 1 && intake.date.month <= 12 ? _months[intake.date.month - 1] : "Unknown"} ${intake.date.day}, ${intake.date.year}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: lightMint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$mealCount FOODS LOGGED',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: lightMint,
                    ),
                  ),
                  const Text(
                    'DENSITY',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (intake.scannedFoods.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...intake.scannedFoods
                .map((foodInfo) => _buildFoodDetailItem(foodInfo))
                .toList(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: darkBg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Totals',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: lightMint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildNutrientChip(
                          'Cals',
                          intake.nutrients['calories'] ?? 0,
                          'kcal',
                          Colors.redAccent),
                      _buildNutrientChip(
                          'Pro',
                          intake.nutrients['protein'] ?? 0,
                          'g',
                          Colors.blueAccent),
                      _buildNutrientChip('Fib', intake.nutrients['fiber'] ?? 0,
                          'g', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodDetailItem(String foodInfo) {
    final foodName = _extractFoodName(foodInfo);
    final foodNutrients = _extractNutrientsFromFood(foodInfo);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentGreen.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, size: 12, color: Colors.greenAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  foodName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (foodNutrients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildSmallNutrientChip(
                    'Cal', foodNutrients['calories'] ?? 0, 'kcal'),
                _buildSmallNutrientChip(
                    'Pro', foodNutrients['protein'] ?? 0, 'g'),
                _buildSmallNutrientChip(
                    'Fib', foodNutrients['fiber'] ?? 0, 'g'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientChip(
      String label, double value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(0)}$unit',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSmallNutrientChip(String label, double value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentGreen),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)}$unit',
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
    );
  }

  String _extractFoodName(String nutritionInfo) {
    final foodNameMatch =
        RegExp(r'FOOD_NAME:\s*(.+?)(?:\n|$)').firstMatch(nutritionInfo);
    return foodNameMatch != null ? foodNameMatch.group(1)!.trim() : 'Food Item';
  }

  Widget _buildPeriodButton(String label) {
    final isSelected = _selectedPeriod == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? secondaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNutrientGrid(List<Widget> nutrientItems) {
    List<Widget> rows = [];
    for (int i = 0; i < nutrientItems.length; i += 2) {
      if (i + 1 < nutrientItems.length) {
        rows.add(Row(children: [
          Expanded(child: nutrientItems[i]),
          const SizedBox(width: 6),
          Expanded(child: nutrientItems[i + 1])
        ]));
      } else {
        rows.add(Row(children: [
          Expanded(child: nutrientItems[i]),
          const Expanded(child: SizedBox())
        ]));
      }
      if (i + 2 < nutrientItems.length) rows.add(const SizedBox(height: 6));
    }
    return rows;
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardEmerald,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.greenAccent,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNutrientItem(
      String name, double value, double target, String unit) {
    final percentage = target > 0 ? (value / target * 100).clamp(0, 200) : 0.0;
    final isGood = percentage >= 50 && percentage <= 120;
    final color = isGood ? Colors.greenAccent : Colors.redAccent;
    final icon = isGood ? Icons.check_circle : Icons.warning_amber;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: darkBg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: lightMint,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              Text('${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(fontSize: 9, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, double> _extractNutrientsFromFood(String nutritionInfo) {
    final nutrients = <String, double>{};
    final caloriesMatch =
        RegExp(r'CALORIES:\s*(\d+(?:\.\d+)?)\s*kcal').firstMatch(nutritionInfo);
    final proteinMatch =
        RegExp(r'PROTEIN:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(nutritionInfo);
    final fiberMatch =
        RegExp(r'FIBER:\s*(\d+(?:\.\d+)?)\s*g').firstMatch(nutritionInfo);
    if (caloriesMatch != null)
      nutrients['calories'] = double.parse(caloriesMatch.group(1)!);
    if (proteinMatch != null)
      nutrients['protein'] = double.parse(proteinMatch.group(1)!);
    if (fiberMatch != null)
      nutrients['fiber'] = double.parse(fiberMatch.group(1)!);
    return nutrients;
  }

  int _getDaysInPeriod() {
    switch (_selectedPeriod) {
      case 'DAY':
        return 1;
      case 'WEEK':
        return 7;
      case 'MONTH':
        return DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      case 'YEAR':
        return 365;
      default:
        return 1;
    }
  }

  double _calculateDayScore(DailyIntake intake) {
    final requirements = widget.profile.dailyNutrientRequirements;
    double totalScore = 0;
    int count = 0;
    requirements.forEach((nutrient, target) {
      final consumed = intake.nutrients[nutrient] ?? 0;
      final percentage = (consumed / target * 100).clamp(0, 150);
      totalScore +=
          percentage > 100 ? 100 - (percentage - 100) * 0.5 : percentage;
      count++;
    });
    return count > 0 ? totalScore / count : 0;
  }
}

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

  factory DailyIntake.fromJson(Map<String, dynamic> json) {
    return DailyIntake(
      date: DateTime.parse(json['date']),
      nutrients: Map<String, double>.from(json['nutrients']),
      totalCalories: json['totalCalories'].toDouble(),
      dailyRequirements: Map<String, double>.from(json['dailyRequirements']),
      scannedFoods: List<String>.from(json['scannedFoods']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'nutrients': nutrients,
      'totalCalories': totalCalories,
      'dailyRequirements': dailyRequirements,
      'scannedFoods': scannedFoods,
    };
  }
}
