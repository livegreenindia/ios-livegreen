import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class WeightUpdateDialog extends StatefulWidget {
  final UserProfile currentProfile;
  final Function(UserProfile) onWeightUpdated;

  const WeightUpdateDialog({
    Key? key,
    required this.currentProfile,
    required this.onWeightUpdated,
  }) : super(key: key);

  @override
  State<WeightUpdateDialog> createState() => _WeightUpdateDialogState();
}

class _WeightUpdateDialogState extends State<WeightUpdateDialog> {
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _weightController.text = widget.currentProfile.weight.toString();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _updateWeight() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newWeight = double.parse(_weightController.text);
      
      // Create updated profile with new weight
      final updatedProfile = UserProfile(
        weight: newWeight,
        height: widget.currentProfile.height,
        age: widget.currentProfile.age,
        gender: widget.currentProfile.gender,
        activityLevel: widget.currentProfile.activityLevel,
        goal: widget.currentProfile.goal,
        state: widget.currentProfile.state,
        healthConditions: widget.currentProfile.healthConditions,
        healthGoals: widget.currentProfile.healthGoals,
      );

      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      final profileJson = json.encode({
        'weight': updatedProfile.weight,
        'height': updatedProfile.height,
        'age': updatedProfile.age,
        'gender': updatedProfile.gender,
        'activityLevel': updatedProfile.activityLevel,
        'goal': updatedProfile.goal,
        'state': updatedProfile.state,
        'healthConditions': updatedProfile.healthConditions,
        'healthGoals': updatedProfile.healthGoals,
      });
      await prefs.setString('user_profile', profileJson);

      // Call callback to update the app state
      widget.onWeightUpdated(updatedProfile);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Weight updated successfully! Nutrient requirements recalculated.'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating weight: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.monitor_weight, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Update Your Weight',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Message
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'It\'s been 15 days! Time to update your weight for accurate nutrition tracking.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Weight: ${widget.currentProfile.weight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'New Weight (kg)',
                      hintText: 'Enter your new weight',
                      prefixIcon: Icon(Icons.monitor_weight, color: Colors.green.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your weight';
                      }
                      final weight = double.tryParse(value);
                      if (weight == null) {
                        return 'Please enter a valid number';
                      }
                      if (weight <= 0 || weight > 500) {
                        return 'Please enter a realistic weight';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateWeight,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                        : const Text('Update Weight'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
