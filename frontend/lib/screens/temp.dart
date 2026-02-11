import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class NutriTrackHistoryApp extends StatelessWidget {
  const NutriTrackHistoryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriTrack - History',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      home: const HistoryPage(),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _selectedIndex = 0;
  String _selectedTab = 'INSIGHTS REPORT';
  String _selectedPeriod = 'DAY';
  
  // Data storage
  List<DailyIntake> _dailyHistory = [];
  Map<String, Map<String, double>> _weeklyAverages = {};
  Map<String, Map<String, double>> _monthlyAverages = {};
  Map<String, Map<String, double>> _yearlyAverages = {};
  
  // Date selection
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    _generateSampleData();
  }

  Future<void> _loadHistoryData() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('dailyIntakeHistory') ?? [];
    
    setState(() {
      try {
        _dailyHistory = historyJson
            .where((json) => json.isNotEmpty)
            .map((json) {
              try {
                final decoded = jsonDecode(json);
                if (decoded is Map<String, dynamic>) {
                  return DailyIntake.fromJson(decoded);
                }
                return null;
              } catch (e) {
                return null;
              }
            })
            .where((item) => item != null)
            .cast<DailyIntake>()
            .toList();
        
        _dailyHistory.sort((a, b) => b.date.compareTo(a.date));
      } catch (e) {
        // If loading fails, use empty list and rely on sample data
        _dailyHistory = [];
      }
      _calculateAverages();
    });
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
        dailyRequirements: {
          'calories': 2000,
          'protein': 50,
          'carbohydrates': 300,
          'fat': 65,
          'fiber': 25,
        },
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

    // Weekly averages
    final Map<String, List<DailyIntake>> weeklyGroups = {};
    for (final intake in _dailyHistory) {
      final weekStart = intake.date.subtract(Duration(days: intake.date.weekday - 1));
      final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
      weeklyGroups.putIfAbsent(weekKey, () => []).add(intake);
    }
    
    _weeklyAverages = {};
    for (final weekKey in weeklyGroups.keys) {
      final weekData = weeklyGroups[weekKey]!;
      if (weekData.isNotEmpty) {
        _weeklyAverages[weekKey] = _calculateAverageNutrients(weekData);
      }
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
      }
    }
  }

  Map<String, double> _calculateAverageNutrients(List<DailyIntake> data) {
    final nutrients = <String, double>{};
    final keys = ['calories', 'protein', 'carbohydrates', 'fat', 'fiber', 'sugar', 'sodium', 'iron', 'calcium', 'vitamin_c'];
    
    for (final key in keys) {
      final total = data.map((d) => d.nutrients[key] ?? 0).reduce((a, b) => a + b);
      nutrients[key] = total / data.length;
    }
    
    return nutrients;
  }

  Map<String, double> _getCurrentPeriodData() {
    switch (_selectedPeriod) {
      case 'DAY':
        final dayData = _dailyHistory.where((intake) =>
          intake.date.year == _selectedDate.year &&
          intake.date.month == _selectedDate.month &&
          intake.date.day == _selectedDate.day
        ).toList();
        return dayData.isNotEmpty ? dayData.first.nutrients : {};
      
      case 'WEEK':
        final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
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
    
    final requirements = {
      'calories': 2000,
      'protein': 50,
      'carbohydrates': 300,
      'fat': 65,
      'fiber': 25,
    };
    
    double totalScore = 0;
    int count = 0;
    
    requirements.forEach((nutrient, target) {
      final consumed = data[nutrient] ?? 0;
      final percentage = (consumed / target * 100).clamp(0, 150);
      totalScore += percentage > 100 ? 100 - (percentage - 100) * 0.5 : percentage;
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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(
          backgroundColor: const Color(0xFF059669),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Intelligence',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ADVANCED HEALTH ANALYTICS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
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
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(Icons.bar_chart, 'Progress', 0),
              const SizedBox(width: 40),
              _buildBottomNavItem(Icons.access_time, 'History', 1),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera feature will be implemented'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          backgroundColor: const Color(0xFF059669),
          child: const Icon(Icons.camera_alt, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label) {
    final isSelected = _selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
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
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(8),
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
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PERIOD SCORE: ${score.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analysis based on $daysCount days of daily activity.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, width: 2),
                  borderRadius: BorderRadius.circular(12),
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
          _buildNutrientItem('Calories', periodData['calories'] ?? 0, 2000, 'kcal'),
          _buildNutrientItem('Protein', periodData['protein'] ?? 0, 50, 'g'),
          _buildNutrientItem('Carbs', periodData['carbohydrates'] ?? 0, 300, 'g'),
          _buildNutrientItem('Fat', periodData['fat'] ?? 0, 65, 'g'),
          _buildNutrientItem('Total Fiber', periodData['fiber'] ?? 0, 25, 'g'),
        ]),

        const SizedBox(height: 16),

        _buildSection('ITEMS TO LIMIT PERFORMANCE', [
          _buildNutrientItem('Added Sugar', periodData['sugar'] ?? 0, 50, 'g'),
          _buildNutrientItem('Sodium', periodData['sodium'] ?? 0, 2300, 'mg'),
        ]),

        const SizedBox(height: 16),

        _buildSection('VITAMINS PERFORMANCE', [
          _buildNutrientItem('Vit C', periodData['vitamin_c'] ?? 0, 90, 'mg'),
          _buildNutrientItem('Iron', periodData['iron'] ?? 0, 18, 'mg'),
          _buildNutrientItem('Calcium', periodData['calcium'] ?? 0, 1000, 'mg'),
        ]),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLogArchive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF9CA3AF),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...List.generate(
          _dailyHistory.take(10).length,
          (index) => _buildLogItem(_dailyHistory[index]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${intake.date.day}',
                style: const TextStyle(
                  color: Color(0xFF059669),
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
                  '${_months[intake.date.month - 1]} ${intake.date.day}, ${intake.date.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$mealCount MEALS LOGGED',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const Text(
                'DENSITY SCORE',
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label) {
    final isSelected = _selectedPeriod == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF059669) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF059669),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                color: Color(0xFF9CA3AF),
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

  Widget _buildNutrientItem(String name, double value, double target, String unit) {
    final percentage = target > 0 ? (value / target * 100).clamp(0, 200) : 0.0;
    final isGood = percentage >= 80 && percentage <= 120;
    final color = isGood ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final icon = isGood ? Icons.check_circle : Icons.warning_amber;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'AVG: ${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final requirements = {
      'calories': 2000,
      'protein': 50,
      'carbohydrates': 300,
      'fat': 65,
      'fiber': 25,
    };
    
    double totalScore = 0;
    int count = 0;
    
    requirements.forEach((nutrient, target) {
      final consumed = intake.nutrients[nutrient] ?? 0;
      final percentage = (consumed / target * 100).clamp(0, 150);
      totalScore += percentage > 100 ? 100 - (percentage - 100) * 0.5 : percentage;
      count++;
    });
    
    return count > 0 ? totalScore / count : 0;
  }
}

// Data models
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