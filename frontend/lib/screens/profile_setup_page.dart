import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/user_profile.dart';
import 'home_screen.dart';

class ProfileSetupPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(UserProfile)? onProfileSaved;
  final UserProfile? existingProfile; // Add this for editing

  const ProfileSetupPage(
      {Key? key,
      required this.cameras,
      this.onProfileSaved,
      this.existingProfile})
      : super(key: key);

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'male';
  String _activityLevel = 'moderate';
  String _selectedState = 'Delhi'; // Add state selection

  // Health conditions and goals
  List<String> _selectedConditions = [];
  Map<String, bool> _selectedGoals = {};

  final List<String> _indianStates = [
    // North India
    'Jammu and Kashmir', 'Ladakh', 'Himachal Pradesh', 'Punjab', 'Uttarakhand',
    'Haryana', 'Delhi', 'Chandigarh', 'Uttar Pradesh', 'Rajasthan',

    // East India
    'Bihar', 'Jharkhand', 'West Bengal', 'Odisha', 'Sikkim',

    // West India
    'Maharashtra', 'Gujarat', 'Goa', 'Dadra and Nagar Haveli and Daman and Diu',

    // South India
    'Andhra Pradesh', 'Telangana', 'Karnataka', 'Kerala', 'Tamil Nadu',
    'Puducherry', 'Lakshadweep', 'Andaman and Nicobar Islands',

    // Central India
    'Madhya Pradesh', 'Chhattisgarh',

    // Northeast India
    'Arunachal Pradesh', 'Assam', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland',
    'Tripura'
  ];

  final List<String> _availableConditions = [
    'Diabetes',
    'High Blood Pressure',
    'Obesity',
    'Thyroid',
    'PCOS/PCOD',
    'Heart Health',
    'Eye Sight',
    'Skin Issues',
    'Fatigue',
    'Stress',
    'Depression',
  ];

  final Map<String, String> _availableGoals = {
    'Improve Focus': 'Enhance mental clarity and concentration',
    'Build Strength': 'Increase muscle mass and physical strength',
    'General Health': 'Maintain overall wellness and vitality',
    'Weight Loss': 'Support healthy weight management',
    'Energy Boost': 'Combat fatigue and increase energy levels',
  };

  @override
  void initState() {
    super.initState();
    // Initialize form with existing profile data if editing
    if (widget.existingProfile != null) {
      _weightController.text = widget.existingProfile!.weight.toString();
      _heightController.text = widget.existingProfile!.height.toString();
      _ageController.text = widget.existingProfile!.age.toString();
      _gender = widget.existingProfile!.gender;
      _activityLevel = widget.existingProfile!.activityLevel;
      _selectedConditions = List.from(widget.existingProfile!.healthConditions);
      _selectedGoals = Map.from(widget.existingProfile!.healthGoals);
      // Load state from profile if available, otherwise use default
      _selectedState = widget.existingProfile!.toJson().containsKey('state')
          ? widget.existingProfile!.toJson()['state'] ?? 'Delhi'
          : 'Delhi';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      // Create temporary profile to calculate automatic goal
      final tempProfile = UserProfile(
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        gender: _gender,
        activityLevel: _activityLevel,
        goal: 'maintain', // Temporary, will be overridden by automatic goal
        state: _selectedState,
        healthConditions: _selectedConditions,
        healthGoals: _selectedGoals,
      );

      final profile = UserProfile(
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        gender: _gender,
        activityLevel: _activityLevel,
        goal: tempProfile.automaticGoal, // Use automatic goal based on BMI
        state: _selectedState,
        healthConditions: _selectedConditions,
        healthGoals: _selectedGoals,
      );

      if (widget.onProfileSaved != null) {
        widget.onProfileSaved!(profile);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomeScreen(cameras: widget.cameras, profile: profile),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Profile'),
          content: const Text(
              'Are you sure you want to delete your profile? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate back to profile setup without existing profile
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileSetupPage(cameras: widget.cameras),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.existingProfile != null ? 'Edit Profile' : 'Profile Setup'),
        centerTitle: true,
        actions: [
          if (widget.existingProfile != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmation(),
              tooltip: 'Delete Profile',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              const Text(
                'Tell us about yourself',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your weight';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Please enter a valid weight';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your height';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Please enter a valid height';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid age';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Gender Selection
              const Text(
                'Gender',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Male'),
                      value: 'male',
                      groupValue: _gender,
                      onChanged: (value) => setState(() => _gender = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Female'),
                      value: 'female',
                      groupValue: _gender,
                      onChanged: (value) => setState(() => _gender = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Health Conditions Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Health Conditions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select any health conditions that affect your nutritional needs:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Show selected conditions prominently
                      if (_selectedConditions.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Conditions:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _selectedConditions
                                    .map((condition) => Chip(
                                          label: Text(
                                            condition,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                          deleteIcon: Icon(Icons.close,
                                              size: 16, color: Colors.white),
                                          onDeleted: () {
                                            setState(() {
                                              _selectedConditions
                                                  .remove(condition);
                                              print(
                                                  'Removed condition via chip: $condition');
                                            });
                                          },
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                      ],

                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _availableConditions
                            .map((condition) => FilterChip(
                                  label: Text(
                                    condition,
                                    style: TextStyle(
                                      color: _selectedConditions
                                              .contains(condition)
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: _selectedConditions
                                              .contains(condition)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  selected:
                                      _selectedConditions.contains(condition),
                                  selectedColor: Colors.green,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: Colors.grey[200],
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedConditions.add(condition);
                                        print('Added condition: $condition');
                                      } else {
                                        _selectedConditions.remove(condition);
                                        print('Removed condition: $condition');
                                      }
                                    });
                                  },
                                  pressElevation:
                                      _selectedConditions.contains(condition)
                                          ? 8
                                          : 2,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Health Goals Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Health Goals',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select your primary health goals:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _availableGoals.entries
                            .map((entry) => FilterChip(
                                  label: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: _selectedGoals[entry.key] == true
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight:
                                          _selectedGoals[entry.key] == true
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                  selected: _selectedGoals[entry.key] ?? false,
                                  selectedColor: Colors.blue,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: Colors.grey[200],
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedGoals[entry.key] = selected;
                                      print(
                                          'Toggled goal ${entry.key}: $selected');
                                    });
                                  },
                                  pressElevation:
                                      _selectedGoals[entry.key] == true ? 8 : 2,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // State/Region Selection
              const Text(
                'State/Region',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'Select your state/region',
                ),
                isExpanded: true,
                items: _indianStates.map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(
                      state,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedState = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Activity Level Selection
              const Text(
                'Activity Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<String>(
                value: _activityLevel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'sedentary', child: Text('Sedentary')),
                  DropdownMenuItem(
                      value: 'light', child: Text('Light (1-3 days/week)')),
                  DropdownMenuItem(
                      value: 'moderate',
                      child: Text('Moderate (3-5 days/week)')),
                  DropdownMenuItem(
                      value: 'active', child: Text('Active (6-7 days/week)')),
                  DropdownMenuItem(
                      value: 'very_active',
                      child: Text('Very Active (2x/day)')),
                ],
                onChanged: (value) => setState(() => _activityLevel = value!),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  child: Text(
                    widget.existingProfile != null
                        ? 'Update Profile'
                        : 'Save Profile',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
