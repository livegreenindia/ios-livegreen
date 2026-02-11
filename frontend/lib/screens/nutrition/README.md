# SuperDiet Nutrition Tracker Integration

## Overview
The SuperDiet feature has been successfully integrated into the LiveGreen app as a nutrition activity in the Activity Page. Users can now track their daily food intake, nutrients (protein, fiber, carbohydrates, etc.) and receive personalized nutrition recommendations based on their profile.

## File Structure

### Models
- **`lib/models/user_profile.dart`** - User profile with BMI calculations and nutrient requirements
- **`lib/models/weight_tracking.dart`** - Weight tracking and weekly summaries

### Nutrition Screens
- **`lib/screens/nutrition/nutrition_home_screen.dart`** - Main nutrition tracking home screen with daily summary
- **`lib/screens/nutrition/nutrition_history_page.dart`** - Historical data view for day/week/month/year
- **`lib/screens/nutrition/nutrition_food_creator_screen.dart`** - Manual food entry form
- **`lib/screens/nutrition/nutrition_main_tab_screen.dart`** - Tab navigation combining home and history

### Activity Integration
- **`lib/screens/pages/activity.dart`** - Updated to handle nutrition activities with new methods:
  - `_isNutritionActivity()` - Detects nutrition-related activities
  - `_navigateToNutritionScreen()` - Routes to nutrition tracker

## Key Features

### 1. Food Tracking
- **Camera/Image Scanning** - Uses Google Generative AI to analyze food images
- **Manual Entry** - Add foods manually with detailed nutrient information
- **Smart Food Search** - Search food database using FoodApiService

### 2. Nutrient Calculation
- Automatic nutrient extraction from food items
- Daily totals calculation for:
  - Calories
  - Protein
  - Carbohydrates
  - Fat
  - Fiber
  - Sodium
  - And more...

### 3. Personal Recommendations
Based on user profile:
- Weight, height, age, gender
- Activity level
- Health goals and conditions
- Indian region/state for localized recommendations

### 4. Analytics & Reporting
- Daily intake tracking
- Weekly averages
- Monthly statistics
- Yearly trends

## How to Access

### From Activity Page
1. Go to Activity page
2. Look for activities with keywords: "Eat", "Food", "Nutrition", "Meal", "Snack", "Diet"
3. Tap on the nutrition activity
4. This will launch the `NutritionMainTabScreen`

### Activity Detection Keywords
The system automatically detects nutrition activities by checking for:
- Title contains: eat, food, nutrition, meal, snack, diet, nutrient, protein, calorie
- Category == 'nutrition'

## Data Storage

### SharedPreferences Keys
- `'user_profile'` - Stores user profile data
- `'dailyIntake_YYYY_M_D'` - Daily intake for specific date
- `'dailyIntakeHistory'` - Complete history list
- `'nutritionData'` - Scanned foods data

## API Integration

### Google Generative AI
- Model: `gemini-2.0-flash-lite`
- Used for: Food image analysis and nutrient extraction
- API Key: Stored in nutrition_home_screen.dart (should be in .env)

### FoodApiService
- Provides food search functionality
- Returns FoodItem objects with nutrition data
- Methods:
  - `searchFood(query, apiKey)` - Search for foods
  - `getFoodDetails(query, apiKey)` - Get detailed nutrition

## Import Structure

All nutrition screens use relative imports for consistency:
```dart
import '../../models/user_profile.dart';
import '../../models/weight_tracking.dart';
import '../../services/food_api_service.dart';
import '../camera_page.dart';  // For camera functionality
import '../nutrition/nutrition_history_page.dart';
```

## Activity Page Integration

The activity page (activity.dart) now includes:

```dart
// Imports
import '../nutrition/nutrition_main_tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import '../../models/user_profile.dart';

// In _showActivityInfo() method
if (_isNutritionActivity(activity)) {
  _navigateToNutritionScreen(context);
  return;
}

// Helper methods
bool _isNutritionActivity(Map<String, dynamic> activity)
void _navigateToNutritionScreen(BuildContext context)
```

## Usage Flow

1. **User Opens Activity Page** → Sees nutrition activity
2. **Taps Nutrition Activity** → Launches NutritionMainTabScreen
3. **Home Tab Options**:
   - Scan food with camera → Analyze with AI
   - Manual entry → Fill nutrition form
4. **History Tab** → View daily/weekly/monthly statistics
5. **Data Persistence** → All data saved to SharedPreferences

## Classes Overview

### DailyIntake
```dart
class DailyIntake {
  DateTime date;
  Map<String, double> nutrients;
  double totalCalories;
  Map<String, double> dailyRequirements;
  List<String> scannedFoods;
}
```

### UserProfile
```dart
class UserProfile {
  double weight, height;
  int age;
  String gender, activityLevel, goal, state;
  List<String> healthConditions;
  Map<String, bool> healthGoals;
  
  // Calculated properties
  double get bmi;
  double get bmr;
  double get tdee;
  Map<String, double> get dailyNutrientRequirements;
}
```

## Error Handling

- User profile validation
- Camera availability check
- Network timeout handling
- Invalid food input detection
- Food vs non-food classification

## Future Enhancements

- [ ] Offline food database
- [ ] Barcode scanning
- [ ] Meal planning
- [ ] Recipe suggestions based on nutrients
- [ ] Integration with health apps
- [ ] Export reports as PDF
- [ ] Nutrition goals and alerts

## Dependencies
- `camera` - For food image capture
- `google_generative_ai` - For AI food analysis
- `shared_preferences` - For local data storage
- `intl` - For date formatting
- Other existing app dependencies

## Testing Checklist

- [x] Navigate to nutrition activity from activity page
- [x] View home screen with daily summary
- [x] Switch between home and history tabs
- [x] Manual food entry form
- [x] User profile loading from SharedPreferences
- [ ] Camera functionality
- [ ] AI analysis of food images
- [ ] Historical data calculations
- [ ] Nutrient requirement calculations

## Notes

- All file paths use relative imports for flexibility
- Nutrition screens are modular and can be used independently
- API key should be moved to environment variables
- Consider implementing state management for better data flow



build.kts


import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.livegreen.app"
    compileSdk = 36
    
    // CHANGE 1: Explicitly pin NDK 26.x. NDK 28 (the current default) is breaking 
    // with older CMake scripts.
    ndkVersion = "26.1.10909125" 

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.livegreen.app"
        minSdk = 26 
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // CHANGE 2: Force the use of CMake 3.22.1 to prevent the "Compiler not set" error
        externalNativeBuild {
            cmake {
                version = "3.22.1"
            }
        }

        val mapsApiKey = keystoreProperties["MAPS_API_KEY"] as String? ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = rootProject.file(storeFilePath)
            }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
    
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.core:core-ktx:1.13.1")
}