import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class FoodApiService {
  static const String _model = 'gemini-2.5-flash-lite';

  /// Search for food using Gemini API
  static Future<List<FoodItem>> searchFood(String query, String apiKey) async {
    try {
      final model = GenerativeModel(
        model: _model,
        apiKey: apiKey,
        requestOptions: RequestOptions(apiVersion: 'v1'),
      );

      final prompt = '''
You are a nutrition expert. Search for nutritional information for the food: "$query"

Provide exactly 5 different variations or serving sizes of this food with their nutritional information.
Format your response as a JSON array with the following structure:

[
  {
    "name": "Food name with serving size",
    "calories": number,
    "protein": number,
    "carbohydrates": number,
    "fat": number,
    "fiber": number,
    "sodium": number,
    "sugar": number,
    "cholesterol": number
  }
]

Example for "apple":
[
  {
    "name": "Medium Apple (182g)",
    "calories": 95,
    "protein": 0.5,
    "carbohydrates": 25,
    "fat": 0.3,
    "fiber": 4.4,
    "sodium": 1,
    "sugar": 19,
    "cholesterol": 0
  }
]

Provide ONLY the JSON array, no additional text.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      try {
        final List<dynamic> jsonData = json.decode(responseText);
        return jsonData.map((item) => FoodItem.fromJson(item)).toList();
      } catch (e) {
        print('Error parsing JSON from Gemini: $e');
        // Fallback: try to extract JSON from response
        final jsonMatch = RegExp(r'\[.*\]').firstMatch(responseText);
        if (jsonMatch != null) {
          final List<dynamic> jsonData = json.decode(jsonMatch.group(0)!);
          return jsonData.map((item) => FoodItem.fromJson(item)).toList();
        }
        return [];
      }
    } catch (e) {
      print('Error searching food with Gemini: $e');
      return [];
    }
  }

  /// Get detailed nutrition information for a specific food
  static Future<FoodItem?> getFoodDetails(String query, String apiKey) async {
    try {
      final model = GenerativeModel(
        model: _model,
        apiKey: apiKey,
        requestOptions: RequestOptions(apiVersion: 'v1'),
      );

      final prompt = '''
You are a nutrition expert. Provide detailed nutritional information for: "$query"

Format your response as a JSON object with the following structure:
{
  "name": "Complete food name with serving size",
  "calories": number,
  "protein": number,
  "carbohydrates": number,
  "fat": number,
  "fiber": number,
  "sodium": number,
  "sugar": number,
  "cholesterol": number
}

Provide ONLY the JSON object, no additional text.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      try {
        final Map<String, dynamic> jsonData = json.decode(responseText);
        return FoodItem.fromJson(jsonData);
      } catch (e) {
        print('Error parsing JSON from Gemini: $e');
        // Fallback: try to extract JSON from response
        final jsonMatch = RegExp(r'\{.*\}').firstMatch(responseText);
        if (jsonMatch != null) {
          final Map<String, dynamic> jsonData = json.decode(jsonMatch.group(0)!);
          return FoodItem.fromJson(jsonData);
        }
        return null;
      }
    } catch (e) {
      print('Error getting food details with Gemini: $e');
      return null;
    }
  }
}

class FoodItem {
  final String name;
  final String? barcode;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sodium;
  final double sugar;
  final double cholesterol;
  final String? brand;
  final String? imageUrl;

  FoodItem({
    required this.name,
    this.barcode,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.fiber = 0.0,
    this.sodium = 0.0,
    this.sugar = 0.0,
    this.cholesterol = 0.0,
    this.brand,
    this.imageUrl,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] ?? 'Unknown Food',
      barcode: json['barcode'],
      calories: _parseNutrient(json['calories']),
      protein: _parseNutrient(json['protein']),
      carbohydrates: _parseNutrient(json['carbohydrates']),
      fat: _parseNutrient(json['fat']),
      fiber: _parseNutrient(json['fiber']),
      sodium: _parseNutrient(json['sodium']),
      sugar: _parseNutrient(json['sugar']),
      cholesterol: _parseNutrient(json['cholesterol']),
      brand: json['brand'],
      imageUrl: json['imageUrl'],
    );
  }

  factory FoodItem.fromEdamamJson(Map<String, dynamic> json) {
    final food = json['food'] ?? {};
    final nutrients = json['food']['nutrients'] ?? {};
    
    return FoodItem(
      name: food['label'] ?? 'Unknown Food',
      barcode: food['foodId'],
      calories: _parseNutrient(nutrients['ENERC_KCAL']),
      protein: _parseNutrient(nutrients['PROCNT']),
      carbohydrates: _parseNutrient(nutrients['CHOCDF']),
      fat: _parseNutrient(nutrients['FAT']),
      fiber: _parseNutrient(nutrients['FIBTG']),
      sodium: _parseNutrient(nutrients['NA']),
      sugar: _parseNutrient(nutrients['SUGAR']),
      cholesterol: _parseNutrient(nutrients['CHOLE']),
      brand: food['brand'],
      imageUrl: food['image'],
    );
  }

  static double _parseNutrient(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toNutrientsMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'sodium': sodium,
      'addedSugar': sugar,
      'cholesterol': cholesterol,
    };
  }

  @override
  String toString() {
    return '''$name${brand != null ? ' ($brand)' : ''}
Calories: ${calories.round()}kcal
Protein: ${protein.round()}g
Carbohydrates: ${carbohydrates.round()}g
Fat: ${fat.round()}g
Fiber: ${fiber.round()}g
Sodium: ${sodium.round()}mg
Added Sugar: ${sugar.round()}g
Cholesterol: ${cholesterol.round()}mg''';
  }
}
