class WeightEntry {
  final DateTime date;
  final double weight;
  final double bmi;
  final double targetWeight;
  final double weeklyChange; // kg change from previous week
  final String? note; // optional note about the entry

  WeightEntry({
    required this.date,
    required this.weight,
    required this.bmi,
    required this.targetWeight,
    this.weeklyChange = 0.0,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
      'bmi': bmi,
      'targetWeight': targetWeight,
      'weeklyChange': weeklyChange,
      'note': note,
    };
  }

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.parse(json['date']),
      weight: json['weight'].toDouble(),
      bmi: json['bmi']?.toDouble() ?? 0.0,
      targetWeight: json['targetWeight']?.toDouble() ?? 0.0,
      weeklyChange: json['weeklyChange']?.toDouble() ?? 0.0,
      note: json['note'],
    );
  }

  // Static method to calculate weight change potential (loss or gain)
  static Map<String, dynamic> calculateWeightChangePotential({
    required double currentWeight,
    required double currentBMI,
    required double targetWeight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) {
    // Calculate safe weight change rate based on medical guidelines
    double safeWeeklyChange;
    double safeMonthlyChange;
    
    if (goal.toLowerCase() == 'lose') {
      // Weight loss calculations
      if (currentBMI > 30) {
        // Obese: Can lose 1kg per week safely
        safeWeeklyChange = 1.0;
        safeMonthlyChange = 4.0;
      } else if (currentBMI > 25) {
        // Overweight: Can lose 0.75kg per week safely
        safeWeeklyChange = 0.75;
        safeMonthlyChange = 3.0;
      } else if (currentBMI > 22) {
        // Slightly overweight: Conservative 0.5kg per week
        safeWeeklyChange = 0.5;
        safeMonthlyChange = 2.0;
      } else {
        // Normal or underweight: Very conservative
        safeWeeklyChange = 0.25;
        safeMonthlyChange = 1.0;
      }
    } else if (goal.toLowerCase() == 'gain') {
      // Weight gain calculations (safer, slower process)
      if (currentBMI < 18.5) {
        // Underweight: Can gain 0.5kg per week safely
        safeWeeklyChange = 0.5;
        safeMonthlyChange = 2.0;
      } else if (currentBMI < 22) {
        // Normal weight: Conservative 0.25kg per week
        safeWeeklyChange = 0.25;
        safeMonthlyChange = 1.0;
      } else {
        // Overweight: Very conservative 0.15kg per week
        safeWeeklyChange = 0.15;
        safeMonthlyChange = 0.6;
      }
    } else {
      // Maintain: No change
      safeWeeklyChange = 0.0;
      safeMonthlyChange = 0.0;
    }

    // Adjust for age (metabolism slows with age)
    if (age > 40) {
      safeWeeklyChange *= 0.8;
      safeMonthlyChange *= 0.8;
    }
    if (age > 50) {
      safeWeeklyChange *= 0.7;
      safeMonthlyChange *= 0.7;
    }

    // Adjust for activity level
    final activityMultipliers = {
      'sedentary': 0.7,
      'light': 0.85,
      'moderate': 1.0,
      'active': 1.15,
      'very_active': 1.3,
    };
    final activityMultiplier = activityMultipliers[activityLevel] ?? 1.0;
    safeWeeklyChange *= activityMultiplier;
    safeMonthlyChange *= activityMultiplier;

    // Calculate time to target
    final weightDifference = targetWeight - currentWeight;
    int weeksToTarget;
    if (weightDifference.abs() < 0.1) {
      weeksToTarget = 0; // Already at target
    } else {
      weeksToTarget = (weightDifference.abs() / safeWeeklyChange.abs()).ceil();
    }

    // Calculate target date
    DateTime targetDate = DateTime.now().add(Duration(days: weeksToTarget * 7));

    // Calculate calorie adjustment
    final dailyCalorieAdjustment = (safeWeeklyChange.abs() * 7 * 7700).round(); // ~7700 cal per kg
    final calorieDirection = goal.toLowerCase() == 'lose' ? 'deficit' : 'surplus';

    return {
      'safeWeeklyChange': safeWeeklyChange,
      'safeMonthlyChange': safeMonthlyChange,
      'weightToChange': weightDifference.abs(),
      'weeksToTarget': weeksToTarget,
      'targetDate': targetDate,
      'recommendedCalorieAdjustment': dailyCalorieAdjustment,
      'calorieDirection': calorieDirection,
      'minTargetWeight': targetWeight,
      'maxHealthyWeight': goal.toLowerCase() == 'lose' ? targetWeight : targetWeight * 1.05,
    };
  }
}

class WeeklyWeightSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double startWeight;
  final double endWeight;
  final double startBMI;
  final double endBMI;
  final double weightChange;
  final double bmiChange;
  final double targetWeight;
  final double averageWeight;
  final int daysTracked;
  final List<WeightEntry> entries;

  WeeklyWeightSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.startWeight,
    required this.endWeight,
    required this.startBMI,
    required this.endBMI,
    required this.weightChange,
    required this.bmiChange,
    required this.targetWeight,
    required this.averageWeight,
    required this.daysTracked,
    required this.entries,
  });

  double get weeklyReduction => weightChange < 0 ? weightChange.abs() : 0.0;
  double get weeklyGain => weightChange > 0 ? weightChange : 0.0;
  double get weeklyBMIReduction => bmiChange < 0 ? bmiChange.abs() : 0.0;
  double get weeklyBMIGain => bmiChange > 0 ? bmiChange : 0.0;
  
  String get weeklyTrend {
    if (weightChange.abs() < 0.1) return 'Maintained';
    if (weightChange < 0) return 'Losing';
    return 'Gaining';
  }

  String get bmiTrend {
    if (bmiChange.abs() < 0.05) return 'Stable';
    if (bmiChange < 0) return 'Improving';
    return 'Increasing';
  }

  double get progressToTarget {
    if (targetWeight <= 0) return 0.0;
    final initialDifference = (entries.first.weight - targetWeight).abs();
    final currentDifference = (endWeight - targetWeight).abs();
    if (initialDifference <= 0) return 100.0;
    return ((initialDifference - currentDifference) / initialDifference * 100).clamp(0.0, 100.0);
  }

  // Weight loss estimation based on current weekly trend
  double get estimatedWeeklyWeightLoss {
    if (daysTracked < 3) return 0.0; // Need at least 3 days of data
    return weeklyReduction;
  }

  // Projected time to reach target based on current trend
  double get estimatedWeeksToTarget {
    if (targetWeight <= 0 || estimatedWeeklyWeightLoss <= 0) return 0.0;
    final remainingWeight = endWeight - targetWeight;
    if (remainingWeight <= 0) return 0.0; // Already at or below target
    return (remainingWeight / estimatedWeeklyWeightLoss).ceil().toDouble();
  }

  // Projected weight loss per month (4 weeks)
  double get estimatedMonthlyWeightLoss {
    return estimatedWeeklyWeightLoss * 4.0;
  }

  // Projected date to reach target
  DateTime? get projectedTargetDate {
    final weeksToTarget = estimatedWeeksToTarget;
    if (weeksToTarget <= 0) return null;
    return DateTime.now().add(Duration(days: (weeksToTarget * 7).round()));
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'startWeight': startWeight,
      'endWeight': endWeight,
      'startBMI': startBMI,
      'endBMI': endBMI,
      'weightChange': weightChange,
      'bmiChange': bmiChange,
      'targetWeight': targetWeight,
      'averageWeight': averageWeight,
      'daysTracked': daysTracked,
      'estimatedWeeklyWeightLoss': estimatedWeeklyWeightLoss,
      'estimatedMonthlyWeightLoss': estimatedMonthlyWeightLoss,
      'estimatedWeeksToTarget': estimatedWeeksToTarget,
      'projectedTargetDate': projectedTargetDate?.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory WeeklyWeightSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyWeightSummary(
      weekStart: DateTime.parse(json['weekStart']),
      weekEnd: DateTime.parse(json['weekEnd']),
      startWeight: json['startWeight'].toDouble(),
      endWeight: json['endWeight'].toDouble(),
      startBMI: json['startBMI']?.toDouble() ?? 0.0,
      endBMI: json['endBMI']?.toDouble() ?? 0.0,
      weightChange: json['weightChange'].toDouble(),
      bmiChange: json['bmiChange']?.toDouble() ?? 0.0,
      targetWeight: json['targetWeight']?.toDouble() ?? 0.0,
      averageWeight: json['averageWeight'].toDouble(),
      daysTracked: json['daysTracked'],
      entries: (json['entries'] as List)
          .map((e) => WeightEntry.fromJson(e))
          .toList(),
    );
  }
}
