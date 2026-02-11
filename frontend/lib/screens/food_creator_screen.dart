import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'history_page.dart';
import '../services/food_api_service.dart';

class FoodCreatorScreen extends StatefulWidget {
  final Function(DailyIntake)? onFoodAdded;
  final String apiKey;

  const FoodCreatorScreen({Key? key, this.onFoodAdded, required this.apiKey}) : super(key: key);

  @override
  State<FoodCreatorScreen> createState() => _FoodCreatorScreenState();
}

class _FoodCreatorScreenState extends State<FoodCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _sugarController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = false;
  List<FoodItem> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sodiumController.dispose();
    _sugarController.dispose();
    _cholesterolController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchFood() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await FoodApiService.searchFood(query, widget.apiKey);
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

  void _selectFoodItem(FoodItem foodItem) {
    setState(() {
      _foodNameController.text = foodItem.name;
      _caloriesController.text = foodItem.calories.round().toString();
      _proteinController.text = foodItem.protein.round().toString();
      _carbsController.text = foodItem.carbohydrates.round().toString();
      _fatController.text = foodItem.fat.round().toString();
      _fiberController.text = foodItem.fiber.round().toString();
      _sodiumController.text = foodItem.sodium.round().toString();
      _sugarController.text = foodItem.sugar.round().toString();
      _cholesterolController.text = foodItem.cholesterol.round().toString();
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _saveFood() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final foodName = _foodNameController.text.trim();
      final nutrients = {
        'calories': double.tryParse(_caloriesController.text) ?? 0.0,
        'protein': double.tryParse(_proteinController.text) ?? 0.0,
        'carbohydrates': double.tryParse(_carbsController.text) ?? 0.0,
        'fat': double.tryParse(_fatController.text) ?? 0.0,
        'fiber': double.tryParse(_fiberController.text) ?? 0.0,
        'sodium': double.tryParse(_sodiumController.text) ?? 0.0,
        'addedSugar': double.tryParse(_sugarController.text) ?? 0.0,
        'cholesterol': double.tryParse(_cholesterolController.text) ?? 0.0,
      };

      // Create food info string similar to camera output
      final foodInfo = '''$foodName
Calories: ${nutrients['calories']?.round()}kcal
Protein: ${nutrients['protein']?.round()}g
Carbohydrates: ${nutrients['carbohydrates']?.round()}g
Fat: ${nutrients['fat']?.round()}g
Fiber: ${nutrients['fiber']?.round()}g
Sodium: ${nutrients['sodium']?.round()}mg
Added Sugar: ${nutrients['addedSugar']?.round()}g
Cholesterol: ${nutrients['cholesterol']?.round()}mg''';

      final historyItem = DailyIntake(
        date: DateTime.now(),
        nutrients: nutrients,
        totalCalories: nutrients['calories'] ?? 0,
        dailyRequirements: {},
        scannedFoods: [],
      );

      widget.onFoodAdded?.call(historyItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$foodName added successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _foodNameController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _fiberController.clear();
    _sodiumController.clear();
    _sugarController.clear();
    _cholesterolController.clear();
    _searchController.clear();
    _searchResults.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Food Entry'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _clearForm,
            icon: const Icon(Icons.clear, color: Colors.white),
            label: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Food with AI',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., Apple, Chicken Breast, Rice',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onFieldSubmitted: (_) => _searchFood(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isSearching ? null : _searchFood,
                          icon: _isSearching
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.search, color: Colors.green),
                        ),
                      ],
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Search Results:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._searchResults.map((foodItem) => ListTile(
                        title: Text(foodItem.name),
                        subtitle: Text(
                            '${foodItem.calories.round()} kcal | ${foodItem.protein.round()}g protein'),
                        trailing: const Icon(Icons.add_circle, color: Colors.green),
                        onTap: () => _selectFoodItem(foodItem),
                      )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Manual Entry Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual Entry',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Food Name
                          TextFormField(
                            controller: _foodNameController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., Grilled Chicken Breast',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.restaurant),
                              labelText: 'Food Name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter food name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Macronutrients
                          const Text(
                            'Macronutrients',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Calories',
                            _caloriesController,
                            'kcal',
                            Icons.local_fire_department,
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Protein',
                            _proteinController,
                            'g',
                            Icons.fitness_center,
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Carbohydrates',
                            _carbsController,
                            'g',
                            Icons.grain,
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Fat',
                            _fatController,
                            'g',
                            Icons.opacity,
                          ),
                          const SizedBox(height: 16),

                          // Other Nutrients
                          const Text(
                            'Other Nutrients',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Fiber',
                            _fiberController,
                            'g',
                            Icons.grass,
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Sodium',
                            _sodiumController,
                            'mg',
                            Icons.restaurant,
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Added Sugar',
                            _sugarController,
                            'g',
                            Icons.cake,
                          ),
                          const SizedBox(height: 12),
                          _buildNutrientField(
                            'Cholesterol',
                            _cholesterolController,
                            'mg',
                            Icons.egg,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveFood,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text('Save to History', style: TextStyle(fontSize: 16)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientField(
    String label,
    TextEditingController controller,
    String unit,
    IconData icon, {
    bool isRequired = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              hintText: '0',
              suffixText: unit,
              border: const OutlineInputBorder(),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return '$label is required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  }
                : (value) {
                    if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
          ),
        ),
      ],
    );
  }
}
