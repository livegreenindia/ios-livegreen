class UserProfile {
  final double weight; // kg
  final double height; // cm
  final int age;
  final String gender; // 'male' or 'female'
  final String activityLevel; // 'sedentary', 'light', 'moderate', 'active', 'very_active'
  final String goal; // 'maintain', 'lose', 'gain'
  final String state; // Indian state/region for localized recommendations
  
  // Health Conditions
  final List<String> healthConditions; // Health conditions that affect nutrient requirements
  final Map<String, bool> healthGoals; // Specific health goals

  UserProfile({
    required this.weight,
    required this.height,
    required this.age,
    required this.gender,
    required this.activityLevel,
    required this.goal,
    this.state = 'Delhi', // Default state
    this.healthConditions = const [],
    this.healthGoals = const {},
  });

  // Calculate BMI
  double get bmi {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  // Get BMI Category and automatic goal
  String get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue < 18.5) return 'underweight';
    if (bmiValue < 25) return 'normal';
    if (bmiValue < 30) return 'overweight';
    return 'obese';
  }

  // Automatically determine goal based on BMI
  String get automaticGoal {
    final category = bmiCategory;
    switch (category) {
      case 'underweight':
        return 'gain_weight';
      case 'overweight':
      case 'obese':
        return 'lose_weight';
      case 'normal':
      default:
        return 'maintain_weight';
    }
  }

  // Calculate BMR using Mifflin-St Jeor Equation
  double get bmr {
    if (gender == 'male') {
      return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }
  }

  // Calculate TDEE (Total Daily Energy Expenditure)
  double get tdee {
    final activityMultipliers = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very_active': 1.9,
    };
    return bmr * (activityMultipliers[activityLevel] ?? 1.2);
  }

  // Calculate daily nutrient requirements with scientific formulas
  Map<String, double> get dailyNutrientRequirements {
    final userWeight = weight;
    final userHeight = height;
    final userAge = age;
    final userGender = gender;
    final isMale = userGender == 'male';
    
    // BMR (Mifflin–St Jeor)
    double bmr;
    if (isMale) {
      bmr = (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) + 5;
    } else {
      bmr = (10 * userWeight) + (6.25 * userHeight) - (5 * userAge) - 161;
    }
    
    // Activity Factor mapping
    final activityFactors = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'heavy': 1.725,
      'very_active': 1.9, // Map 'very_active' to 'athlete'
      'active': 1.725, // Map 'active' to 'heavy'
    };
    final af = activityFactors[activityLevel] ?? 1.2;
    
    // TDEE (Maintenance Calories)
    double tdee = bmr * af;
    
    // Calorie Adjustment based on automatic BMI-based goal
    double calories;
    final autoGoal = automaticGoal;
    if (autoGoal.toLowerCase().contains('lose')) {
      calories = tdee - 500;
    } else if (autoGoal.toLowerCase().contains('gain')) {
      calories = tdee + 300;
    } else {
      calories = tdee; // maintenance
    }
    
    // Protein Multiplier (g/kg)
    double proteinFactor;
    if (af <= 1.2) {
      proteinFactor = 0.8;
    } else if (af <= 1.375) {
      proteinFactor = 1.0;
    } else if (af <= 1.55) {
      proteinFactor = 1.2;
    } else if (af <= 1.725) {
      proteinFactor = 1.6;
    } else {
      proteinFactor = 2.0;
    }
    
    if (userAge >= 60) {
      proteinFactor = proteinFactor + 0.2;
    }
    
    // Protein (grams/day)
    final protein = proteinFactor * userWeight;
    
    // Fat Percentage
    double fatPercent;
    if (af <= 1.375) {
      fatPercent = 0.30;
    } else if (af <= 1.55) {
      fatPercent = 0.25;
    } else {
      fatPercent = 0.20;
    }
    
    // Fat (grams/day)
    final fat = (fatPercent * calories) / 9;
    
    // Carbohydrates (grams/day)
    final carbs = (calories - ((protein * 4) + (fat * 9))) / 4;
    
    // Fiber (grams/day)
    final fiber = (calories / 1000) * 14;
    
    // Fiber Breakdown (grams/day)
    final totalFiber = fiber;
    final solubleFiber = totalFiber * 0.4; // 40% of total fiber
    final insolubleFiber = totalFiber * 0.6; // 60% of total fiber
    final prebioticFiber = totalFiber * 0.3; // 30% of total fiber
    
    // Water (liters/day)
    double water = 0.033 * userWeight;
    if (af >= 1.55) {
      water = water + 0.5;
    }
    
    // Sodium (mg/day)
    double sodium = 2000;
    if (af >= 1.55) {
      sodium = sodium + 500;
    }
    
    // Calcium (mg/day)
    final calcium = userAge < 50 ? 1000.0 : 1200.0;
    
    // Iron (mg/day)
    double iron = isMale ? 8.0 : 18.0;
    if (af >= 1.725) {
      iron = iron * 1.3;
    }
    
    // Potassium (mg/day)
    final potassium = 4700.0;
    
    // Magnesium (mg/day)
    final magnesium = 6 * userWeight;
    
    // Zinc (mg/day)
    final zinc = 0.14 * userWeight;
    
    // Vitamin D (IU/day)
    final vitaminD = userAge >= 60 ? 1000.0 : 800.0;
    
    // Vitamin C (mg/day)
    double vitaminC = isMale ? 90.0 : 75.0;
    if (af >= 1.55) {
      vitaminC = vitaminC + 15;
    }
    
    // Vitamin B12 (mcg/day)
    final vitaminB12 = userAge >= 50 ? 3.0 : 2.4;
    
    // Vitamin B6 (mg/day)
    final vitaminB6 = 0.02 * userWeight;
    
    // Vitamin K (mcg/day)
    final vitaminK = 1 * userWeight;
    
    // Get base requirements
    final baseRequirements = {
      // Macronutrients
      'calories': calories, 'protein': protein, 'carbohydrates': carbs, 'fat': fat, 'fiber': fiber, 'water': water,
      
      // Fiber Breakdown
      'totalFiber': totalFiber, 'solubleFiber': solubleFiber, 'insolubleFiber': insolubleFiber, 'prebioticFiber': prebioticFiber,
      
      // Vitamins
      'vitaminA': isMale ? 900.0 : 700.0, 'vitaminC': vitaminC, 'vitaminD': vitaminD,
      'vitaminE': 15.0, 'vitaminK': vitaminK, 'vitaminB1': 1.2, 'vitaminB2': 1.3,
      'vitaminB3': 16.0, 'vitaminB5': 5.0, 'vitaminB6': vitaminB6, 'vitaminB7': 30.0,
      'vitaminB9': 400.0, 'folate': 400.0, 'vitaminB12': vitaminB12,
      
      // Minerals
      'calcium': calcium, 'iron': iron, 'potassium': potassium, 'magnesium': magnesium, 'zinc': zinc,
      'sodium': sodium, 'phosphorus': 700.0, 'copper': 0.9, 'manganese': 2.3, 'selenium': 55.0,
      
      // Health-limiting nutrients
      'cholesterol': 300.0, 'omega3': isMale ? 1.6 : 1.1, 'omega6': 10.0, 'monounsaturatedFat': fat * 0.4,
      'addedSugar': calories * 0.10 / 4, // 10% of calories
      'saturatedFat': calories * 0.10 / 9, // 10% of calories
      'transFat': 2.0,
      'refinedCarbs': calories * 0.05 / 4, // 5% of calories
    };
    
    // Apply health condition adjustments
    final adjustments = healthConditionAdjustments;
    final stateAdjustments = _getStateBasedAdjustments();
    final adjustedRequirements = <String, double>{};
    
    baseRequirements.forEach((nutrient, baseValue) {
      double adjustedValue = baseValue;
      
      // Apply health condition adjustments
      if (adjustments.containsKey(nutrient)) {
        final adjustment = adjustments[nutrient]!;
        adjustedValue = baseValue * (1 + adjustment);
      }
      
      // Apply state-based adjustments
      if (stateAdjustments.containsKey(nutrient)) {
        final stateAdjustment = stateAdjustments[nutrient]!;
        adjustedValue = adjustedValue * (1 + stateAdjustment);
      }
      
      adjustedRequirements[nutrient] = adjustedValue;
    });
    
    return adjustedRequirements;
  }

  // Estimate ideal weight using Devine formula and BMI-based calculations
  Map<String, dynamic> get weightEstimation {
    final userHeight = height;
    final userGender = gender;
    final userAge = age;
    final isMale = userGender == 'male';
    
    // Devine formula for ideal body weight (kg)
    double idealWeight;
    if (isMale) {
      idealWeight = 50 + 2.3 * ((userHeight / 2.54) - 60); // 50kg + 2.3kg per inch over 5ft
    } else {
      idealWeight = 45.5 + 2.3 * ((userHeight / 2.54) - 60); // 45.5kg + 2.3kg per inch over 5ft
    }
    
    // BMI-based weight range (healthy BMI: 18.5-24.9)
    final heightInMeters = userHeight / 100;
    final minHealthyWeight = 18.5 * (heightInMeters * heightInMeters);
    final maxHealthyWeight = 24.9 * (heightInMeters * heightInMeters);
    
    // Age adjustment (metabolism slows with age)
    if (userAge > 40) {
      idealWeight += (userAge - 40) * 0.1; // Add 0.1kg per year after 40
    }
    
    // Current BMI
    final currentBMI = weight / (heightInMeters * heightInMeters);
    
    // Weight difference and recommendation
    final weightDifference = weight - idealWeight;
    String recommendation;
    String weightStatus;
    
    if (currentBMI < 18.5) {
      weightStatus = 'Underweight';
      recommendation = 'Consider gaining weight to reach healthy BMI range';
    } else if (currentBMI >= 18.5 && currentBMI < 25) {
      weightStatus = 'Normal Weight';
      recommendation = 'Your weight is within healthy range';
    } else if (currentBMI >= 25 && currentBMI < 30) {
      weightStatus = 'Overweight';
      recommendation = 'Consider losing weight to reach healthy BMI range';
    } else {
      weightStatus = 'Obese';
      recommendation = 'Weight loss recommended for health reasons';
    }
    
    // Adjusted target weight based on goal
    double targetWeight;
    switch (goal.toLowerCase()) {
      case 'lose':
        targetWeight = idealWeight * 0.95; // 5% less than ideal
        break;
      case 'gain':
        targetWeight = idealWeight * 1.05; // 5% more than ideal
        break;
      default:
        targetWeight = idealWeight;
    }
    
    return {
      'currentWeight': weight,
      'idealWeight': idealWeight.roundToDouble(),
      'targetWeight': targetWeight.roundToDouble(),
      'minHealthyWeight': minHealthyWeight.roundToDouble(),
      'maxHealthyWeight': maxHealthyWeight.roundToDouble(),
      'currentBMI': currentBMI.roundToDouble(),
      'weightStatus': weightStatus,
      'recommendation': recommendation,
      'weightDifference': weightDifference.roundToDouble(),
      'healthyRange': '${minHealthyWeight.roundToDouble()} - ${maxHealthyWeight.roundToDouble()} kg',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'height': height,
      'age': age,
      'gender': gender,
      'activityLevel': activityLevel,
      'goal': goal,
      'state': state,
      'healthConditions': healthConditions,
      'healthGoals': healthGoals,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      weight: json['weight']?.toDouble() ?? 0.0,
      height: json['height']?.toDouble() ?? 0.0,
      age: json['age']?.toInt() ?? 0,
      gender: json['gender'] ?? '',
      activityLevel: json['activityLevel'] ?? '',
      goal: json['goal'] ?? '',
      state: json['state'] ?? 'Delhi',
      healthConditions: List<String>.from(json['healthConditions'] ?? []),
      healthGoals: Map<String, bool>.from(json['healthGoals'] ?? {}),
    );
  }

  // Health condition-specific nutrient adjustments
  Map<String, double> get healthConditionAdjustments {
    final adjustments = <String, double>{};
    
    for (final condition in healthConditions) {
      switch (condition.toLowerCase()) {
        case 'diabetes':
          adjustments['carbohydrates'] = -0.20; // 20% reduction
          adjustments['addedSugar'] = -0.50; // 50% reduction
          adjustments['fiber'] = 0.30; // 30% increase
          break;
          
        case 'high blood pressure':
          adjustments['sodium'] = -0.60; // 60% reduction
          adjustments['potassium'] = 0.25; // 25% increase
          adjustments['magnesium'] = 0.20; // 20% increase
          break;
          
        case 'obesity':
          adjustments['protein'] = 0.25; // 25% increase for satiety
          adjustments['fiber'] = 0.40; // 40% increase
          adjustments['carbohydrates'] = -0.15; // 15% reduction
          adjustments['fat'] = -0.10; // 10% reduction
          break;
          
        case 'thyroid':
          adjustments['iodine'] = 0.50; // 50% increase (if available)
          adjustments['selenium'] = 0.30; // 30% increase
          adjustments['zinc'] = 0.20; // 20% increase
          break;
          
        case 'pcos/pcod':
          adjustments['fiber'] = 0.35; // 35% increase
          adjustments['protein'] = 0.15; // 15% increase
          adjustments['carbohydrates'] = -0.20; // 20% reduction (low GI focus)
          adjustments['vitaminD'] = 0.40; // 40% increase
          adjustments['chromium'] = 0.50; // 50% increase (if available)
          break;
          
        case 'heart health':
          adjustments['omega3'] = 1.0; // 100% increase
          adjustments['fiber'] = 0.25; // 25% increase
          adjustments['saturatedFat'] = -0.30; // 30% reduction
          adjustments['transFat'] = -0.50; // 50% reduction
          adjustments['sodium'] = -0.40; // 40% reduction
          break;
          
        case 'eye sight':
          adjustments['vitaminA'] = 0.30; // 30% increase
          adjustments['vitaminC'] = 0.25; // 25% increase
          adjustments['vitaminE'] = 0.40; // 40% increase
          adjustments['zinc'] = 0.20; // 20% increase
          adjustments['lutein'] = 0.50; // 50% increase (if available)
          break;
          
        case 'skin issues':
          adjustments['vitaminA'] = 0.25; // 25% increase
          adjustments['vitaminC'] = 0.30; // 30% increase
          adjustments['vitaminE'] = 0.35; // 35% increase
          adjustments['zinc'] = 0.25; // 25% increase
          adjustments['omega3'] = 0.40; // 40% increase
          break;
          
        case 'fatigue':
          adjustments['iron'] = 0.30; // 30% increase
          adjustments['vitaminB12'] = 0.40; // 40% increase
          adjustments['magnesium'] = 0.25; // 25% increase
          adjustments['coenzymeQ10'] = 0.50; // 50% increase (if available)
          break;
          
        case 'stress':
          adjustments['vitaminC'] = 0.40; // 40% increase
          adjustments['magnesium'] = 0.30; // 30% increase
          adjustments['vitaminB6'] = 0.35; // 35% increase
          adjustments['omega3'] = 0.50; // 50% increase
          break;
          
        case 'depression':
          adjustments['vitaminD'] = 0.50; // 50% increase
          adjustments['omega3'] = 0.60; // 60% increase
          adjustments['vitaminB12'] = 0.30; // 30% increase
          adjustments['folate'] = 0.25; // 25% increase
          break;
          
        case 'improve focus':
          adjustments['omega3'] = 0.40; // 40% increase
          adjustments['vitaminB6'] = 0.30; // 30% increase
          adjustments['vitaminB12'] = 0.25; // 25% increase
          adjustments['iron'] = 0.20; // 20% increase
          break;
          
        case 'build strength':
          adjustments['protein'] = 0.50; // 50% increase
          adjustments['creatine'] = 0.50; // 50% increase (if available)
          adjustments['vitaminD'] = 0.30; // 30% increase
          adjustments['magnesium'] = 0.25; // 25% increase
          adjustments['zinc'] = 0.20; // 20% increase
          break;
      }
    }
    
    return adjustments;
  }

  // State-based nutrient adjustments based on regional dietary patterns
  Map<String, double> _getStateBasedAdjustments() {
    final adjustments = <String, double>{};
    
    switch (state.toLowerCase()) {
      // Himalayan Region - High altitude, cold climate
      case 'jammu and kashmir':
      case 'ladakh':
      case 'himachal pradesh':
      case 'uttarakhand':
        adjustments['fat'] = 0.30; // 30% increase for energy in cold climate
        adjustments['protein'] = 0.25; // 25% increase for muscle maintenance
        adjustments['carbohydrates'] = 0.20; // 20% increase for energy
        adjustments['vitaminD'] = 0.40; // 40% increase due to limited sun exposure
        adjustments['iron'] = 0.30; // 30% increase for high altitude
        adjustments['calories'] = 0.25; // 25% increase for thermogenesis
        break;
        
      // North Indian Plains - Wheat-based, dairy-rich
      case 'punjab':
      case 'haryana':
      case 'delhi':
      case 'chandigarh':
      case 'western uttar pradesh':
        adjustments['protein'] = 0.20; // 20% increase for dairy-rich diet
        adjustments['calcium'] = 0.30; // 30% increase for dairy consumption
        adjustments['carbohydrates'] = 0.15; // 15% increase for wheat-based diet
        adjustments['fiber'] = 0.10; // 10% increase
        adjustments['vitaminB12'] = 0.25; // 25% increase for dairy/meat
        break;
        
      // Rajasthan - Desert climate, preserved foods
      case 'rajasthan':
        adjustments['fat'] = 0.25; // 25% increase for energy in desert
        adjustments['sodium'] = 0.40; // 40% increase for preserved foods
        adjustments['protein'] = 0.15; // 15% increase for lentils/gram flour
        adjustments['vitaminC'] = 0.30; // 30% increase for immunity
        adjustments['water'] = 0.20; // 20% increase for hydration needs
        break;
        
      // East India - Rice-based, fish-rich coastal areas
      case 'west bengal':
      case 'odisha':
        adjustments['protein'] = 0.15; // 15% increase for fish/eggs
        adjustments['omega3'] = 0.40; // 40% increase for fish consumption
        adjustments['carbohydrates'] = 0.10; // 10% increase for rice-based diet
        adjustments['vitaminD'] = 0.20; // 20% increase for coastal sun exposure
        adjustments['iodine'] = 0.25; // 25% increase for coastal iodine
        break;
        
      // Bihar & Jharkhand - Agricultural, mixed diet
      case 'bihar':
      case 'jharkhand':
        adjustments['carbohydrates'] = 0.20; // 20% increase for rice/wheat
        adjustments['protein'] = 0.10; // 10% increase for lentils
        adjustments['fiber'] = 0.25; // 25% increase for vegetarian diet
        adjustments['iron'] = 0.20; // 20% increase for agricultural population
        break;
        
      // West India - Diverse coastal and inland patterns
      case 'maharashtra':
        adjustments['protein'] = 0.12; // 12% increase for mixed diet
        adjustments['fiber'] = 0.20; // 20% increase for millets/jowar
        adjustments['carbohydrates'] = 0.10; // 10% increase for rice/jowar
        break;
        
      case 'gujarat':
        adjustments['carbohydrates'] = 0.15; // 15% increase for wheat/rice
        adjustments['protein'] = 0.10; // 10% increase for dairy/lentils
        adjustments['fiber'] = 0.25; // 25% increase for vegetarian diet
        adjustments['fat'] = 0.15; // 15% increase for ghee/oil
        break;
        
      case 'goa':
        adjustments['protein'] = 0.20; // 20% increase for fish/meat
        adjustments['omega3'] = 0.35; // 35% increase for coastal fish diet
        adjustments['vitaminD'] = 0.25; // 25% increase for beach lifestyle
        adjustments['sodium'] = 0.20; // 20% increase for seafood preservation
        break;
        
      // South India - Rice-based, coconut-rich, spicy
      case 'tamil nadu':
      case 'andhra pradesh':
      case 'telangana':
        adjustments['carbohydrates'] = 0.25; // 25% increase for rice-based diet
        adjustments['fiber'] = 0.30; // 30% increase for high fiber foods
        adjustments['protein'] = 0.08; // 8% increase for lentils/legumes
        adjustments['sodium'] = 0.25; // 25% increase for salt-heavy foods
        adjustments['vitaminC'] = 0.20; // 20% increase for tamarind/lemon
        break;
        
      case 'karnataka':
        adjustments['carbohydrates'] = 0.20; // 20% increase for rice/millets
        adjustments['protein'] = 0.12; // 12% increase for mixed diet
        adjustments['fiber'] = 0.25; // 25% increase for diverse foods
        break;
        
      case 'kerala':
        adjustments['fat'] = 0.30; // 30% increase for coconut oil
        adjustments['protein'] = 0.15; // 15% increase for fish/meat
        adjustments['omega3'] = 0.25; // 25% increase for coastal fish
        adjustments['vitaminD'] = 0.20; // 20% increase for coastal sun
        adjustments['fiber'] = 0.20; // 20% increase for plant-based foods
        break;
        
      // Central India - Mixed agricultural patterns
      case 'madhya pradesh':
      case 'chhattisgarh':
        adjustments['carbohydrates'] = 0.18; // 18% increase for wheat/rice
        adjustments['protein'] = 0.10; // 10% increase for lentils
        adjustments['fiber'] = 0.20; // 20% increase for tribal foods
        adjustments['iron'] = 0.25; // 25% increase for tribal population
        break;
        
      // Northeast India - Unique tribal diets, high protein
      case 'arunachal pradesh':
      case 'assam':
      case 'manipur':
      case 'meghalaya':
      case 'mizoram':
      case 'nagaland':
      case 'tripura':
        adjustments['protein'] = 0.25; // 25% increase for meat/fish
        adjustments['fat'] = 0.20; // 20% increase for energy in hilly terrain
        adjustments['carbohydrates'] = 0.15; // 15% increase for rice
        adjustments['fiber'] = 0.30; // 30% increase for bamboo shoots/local vegetables
        adjustments['vitaminC'] = 0.25; // 25% increase for citrus fruits
        adjustments['omega3'] = 0.20; // 20% increase for river fish
        break;
        
      // Union Territories - Island/coastal regions
      case 'andaman and nicobar islands':
        adjustments['protein'] = 0.20; // 20% increase for seafood
        adjustments['omega3'] = 0.45; // 45% increase for marine fish
        adjustments['vitaminD'] = 0.35; // 35% increase for tropical sun
        adjustments['sodium'] = 0.30; // 30% increase for seafood preservation
        break;
        
      case 'lakshadweep':
        adjustments['protein'] = 0.25; // 25% increase for fish-based diet
        adjustments['omega3'] = 0.50; // 50% increase for marine fish
        adjustments['vitaminD'] = 0.40; // 40% increase for island sun exposure
        break;
        
      case 'puducherry':
        adjustments['carbohydrates'] = 0.15; // 15% increase for rice-based diet
        adjustments['protein'] = 0.12; // 12% increase for mixed diet
        adjustments['fat'] = 0.10; // 10% increase for French influence
        break;
        
      case 'dadra and nagar haveli and daman and diu':
        adjustments['protein'] = 0.15; // 15% increase for mixed diet
        adjustments['carbohydrates'] = 0.12; // 12% increase for rice/wheat
        break;
    }
    
    return adjustments;
  }
}
