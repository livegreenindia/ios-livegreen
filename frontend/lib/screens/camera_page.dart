import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_profile.dart';

class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String apiKey;
  final UserProfile? userProfile;
  final Function(String)? onFoodAnalyzed;
  final VoidCallback? onClose;

  const CameraPage({
    super.key,
    required this.cameras,
    required this.apiKey,
    this.userProfile,
    this.onFoodAnalyzed,
    this.onClose,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _nutritionInfo = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
    );
    
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Only dispose camera controller if it exists
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _selectedImage = File(image.path);
        _nutritionInfo = '';
      });
      
      // Don't dispose camera immediately - keep it available for retake
      await _analyzeFood();
    } catch (e) {
      _showError('Error taking picture: $e');
      // Reinitialize camera on error
      await _initializeCamera();
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _nutritionInfo = '';
        });
        await _analyzeFood();
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _selectedImage = null;
      _nutritionInfo = '';
    });
    // Only initialize camera if it's not already initialized
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
    }
  }

  Future<void> _analyzeFood() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _nutritionInfo = '';
    });

    try {
      print("Attempting to use Gemini API with model: gemini-2.5-flash-lite");
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: widget.apiKey,
        requestOptions: RequestOptions(apiVersion: 'v1'),
      );

      final imageBytes = await _selectedImage!.readAsBytes();
      
      final prompt = TextPart(
        'You are a nutrition expert. Analyze this image and determine if it contains food. '
        'If it does NOT contain food, respond with exactly: "This is not food" and nothing else.\n\n'
        'If it DOES contain food, consider the user\'s health profile and provide personalized analysis:\n\n'
        '${widget.userProfile != null ? '''
        USER HEALTH PROFILE:
        - Health Conditions: ${widget.userProfile!.healthConditions.join(', ')}
        - Health Goals: ${widget.userProfile!.healthGoals.keys.join(', ')}
        - Daily Requirements: ${widget.userProfile!.dailyNutrientRequirements.entries.map((e) => '${e.key}: ${e.value.round()}').join(', ')}
        
        IMPORTANT: Adjust your analysis based on these health conditions:
        - Diabetes: Focus on low glycemic index, reduce carbs/sugar, increase fiber
        - High Blood Pressure: Focus on low sodium, increase potassium/magnesium
        - Heart Health: Focus on low saturated/trans fat, increase omega3/fiber
        - Obesity: Focus on high protein/fiber, reduced calories/carbs/fat
        - PCOS/PCOD: Focus on low glycemic index, high fiber/protein
        - Eye Sight: Focus on vitamin A, C, E, lutein-rich foods
        - Skin Issues: Focus on vitamins A, C, E, zinc, omega3
        - Fatigue: Focus on iron, B12, magnesium, energy-boosting nutrients
        - Stress: Focus on vitamin C, magnesium, B6, omega3
        - Depression: Focus on vitamin D, omega3, B12, folate
        - Build Strength: Focus on high protein, vitamin D, magnesium, zinc
        
        ''' : ''}'
        'Format your response EXACTLY like this:\n\n'
        'FOOD_NAME: [Specific food name - e.g., "Grilled Chicken Breast", "Medium Apple", "Brown Rice Bowl"]\n'
        'SERVING_SIZE: [Estimated serving size - e.g., "1 cup (200g)", "1 medium (182g)", "1 slice (28g)"]\n'
        'CALORIES: [number] kcal\n'
        'PROTEIN: [number] g\n'
        'CARBOHYDRATES: [number] g\n'
        'FAT: [number] g\n'
        'FIBER: [number] g\n'
        'SODIUM: [number] mg\n'
        'ADDED SUGAR: [number] g\n'
        'TRANS FAT: [number] g\n'
        'SATURATED FAT: [number] g\n'
        'REFINED CARBS: [number] g\n'
        'CHOLESTEROL: [number] mg\n'
        
        // Fiber Breakdown
        'TOTAL FIBER: [number] g\n'
        'SOLUBLE FIBER: [number] g\n'
        'INSOLUBLE FIBER: [number] g\n'
        'PREBIOTIC FIBER: [number] g\n'
        
        // Fat Breakdown
        'MONOUNSATURATED FAT: [number] g\n'
        'OMEGA-3: [number] g\n'
        'OMEGA-6: [number] g\n'
        
        // Vitamins (Complete Set)
        'VITAMIN A: [number] mcg\n'
        'VITAMIN C: [number] mg\n'
        'VITAMIN D: [number] mcg\n'
        'VITAMIN E: [number] mg\n'
        'VITAMIN K: [number] mcg\n'
        'VITAMIN B1: [number] mg\n'
        'VITAMIN B2: [number] mg\n'
        'VITAMIN B3: [number] mg\n'
        'VITAMIN B5: [number] mg\n'
        'VITAMIN B6: [number] mg\n'
        'VITAMIN B7: [number] mcg\n'
        'VITAMIN B9: [number] mcg\n'
        'VITAMIN B12: [number] mcg\n'
        'FOLATE: [number] mcg\n'
        
        // Minerals (Complete Set)
        'CALCIUM: [number] mg\n'
        'IRON: [number] mg\n'
        'POTASSIUM: [number] mg\n'
        'MAGNESIUM: [number] mg\n'
        'ZINC: [number] mg\n'
        'PHOSPHORUS: [number] mg\n'
        'COPPER: [number] mg\n'
        'MANGANESE: [number] mg\n'
        'SELENIUM: [number] mcg\n\n'
        'CRITICAL INSTRUCTIONS:\n'
        '- MUST start with "FOOD_NAME:" followed by the specific food name\n'
        '- MUST include "SERVING_SIZE:" with estimated portion\n'
        '- Provide REALISTIC nutritional values based on standard nutritional databases\n'
        '- Consider the visible portion size in the image\n'
        '- Use common serving sizes as reference\n'
        '- Do NOT return zeros unless the food truly contains none of that nutrient\n'
        '- Example: A medium apple has ~95 calories, 0.5g protein, 25g carbs, 0.3g fat\n'
        '- Example: A slice of bread has ~80 calories, 3g protein, 15g carbs, 1g fat\n'
        '- If you cannot identify the food specifically, use "Mixed Food Item" as food name'
      );

      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      setState(() {
        _nutritionInfo = response.text ?? 'No response from API';
        _isLoading = false;
      });
      
      print("AI Response: ${response.text ?? 'Empty'}");
      
      // Check if the response indicates non-food
      if (_nutritionInfo.toLowerCase().contains('this is not food')) {
        _showNotFoodDialog();
        setState(() {
          _nutritionInfo = '';
        });
        return;
      }
      
      // If AI returns empty or minimal response, provide a fallback
      if (_nutritionInfo.isEmpty || _nutritionInfo.length < 20) {
        _showManualInputDialog();
        return;
      }

      // Show confirmation dialog instead of automatically saving
      _showConfirmationDialog();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error analyzing food: $e');
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Confirm Food Analysis'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food has been analyzed successfully!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(
                    maxHeight: 300, // Limit height but allow scrolling
                  ),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutritional Information:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _nutritionInfo,
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Do you want to save this to your nutrient history?',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                // Cancel - don't save, but still go to nutrient page
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Food analysis cancelled'),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
                
                // Wait a moment, then navigate to history tab
                await Future.delayed(const Duration(seconds: 2));
                
                // Call the close callback to switch to home tab first, then to history
                if (mounted) {
                  widget.onClose?.call();
                  // After a short delay, switch to history tab (index 2)
                  Future.delayed(const Duration(milliseconds: 500), () {
                    // Find the TabController and switch to history tab
                    final tabController = DefaultTabController.of(context);
                    tabController.animateTo(2); // Switch to History tab
                  });
                }
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                // Okay - save the nutrition info
                print('=== CALLING FOOD ANALYZED CALLBACK ===');
                print('Nutrition info to send: ${_nutritionInfo.substring(0, 100)}...');
                
                // Only call onFoodAnalyzed if it's not null
                widget.onFoodAnalyzed?.call(_nutritionInfo);
                
                print('=== FOOD ANALYZED CALLBACK CALLED ===');
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Food saved successfully!'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                
                // Wait a moment, then navigate to history tab
                await Future.delayed(const Duration(seconds: 2));
                
                // Call the close callback to switch to home tab first, then to history
                if (mounted) {
                  widget.onClose?.call();
                  // After a short delay, switch to history tab (index 2)
                  Future.delayed(const Duration(milliseconds: 500), () {
                    // Find the TabController and switch to history tab
                    final tabController = DefaultTabController.of(context);
                    tabController.animateTo(2); // Switch to History tab
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Okay'),
            ),
          ],
        );
      },
    );
  }

  void _showManualInputDialog() {
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final addedSugarController = TextEditingController();
    final transFatController = TextEditingController();
    final saturatedFatController = TextEditingController();
    final refinedCarbsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Nutrition Info Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                decoration: InputDecoration(labelText: 'Calories (kcal)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: proteinController,
                decoration: InputDecoration(labelText: 'Protein (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: carbsController,
                decoration: InputDecoration(labelText: 'Carbohydrates (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: fatController,
                decoration: InputDecoration(labelText: 'Fat (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: addedSugarController,
                decoration: InputDecoration(labelText: 'Added Sugar (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: transFatController,
                decoration: InputDecoration(labelText: 'Trans Fat (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: saturatedFatController,
                decoration: InputDecoration(labelText: 'Saturated Fat (g)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: refinedCarbsController,
                decoration: InputDecoration(labelText: 'Refined Carbs (g)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final manualInfo = 'FOOD_NAME: Manual Entry\n'
                  'CALORIES: ${caloriesController.text} kcal\n'
                  'PROTEIN: ${proteinController.text} g\n'
                  'CARBOHYDRATES: ${carbsController.text} g\n'
                  'FAT: ${fatController.text} g\n'
                  'Added Sugar: ${addedSugarController.text}g\n'
                  'Trans Fat: ${transFatController.text}g\n'
                  'Saturated Fat: ${saturatedFatController.text}g\n'
                  'Refined Carbs: ${refinedCarbsController.text}g';
              
              setState(() {
                _nutritionInfo = manualInfo;
                _isLoading = false;
              });
              
              Navigator.of(context).pop();
              
              // Show confirmation dialog for manual entry too
              _showConfirmationDialog();
            },
            child: Text('Use These Values'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showNotFoodDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Not Food'),
            ],
          ),
          content: Text(
            'This image doesn\'t appear to contain food. Please try again with a food item.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous page
              },
              child: Text('Go Back'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog only
                _retakePhoto(); // Allow retake
              },
              child: Text('Retake'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scanner'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Dispose camera and call close callback
              _cameraController?.dispose().then((_) {
                _cameraController = null;
                // Call the close callback if provided
                widget.onClose?.call();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview or Selected Image
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.contain)
                  : (_cameraController?.value.isInitialized ?? false)
                      ? CameraPreview(_cameraController!)
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            child: _selectedImage != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _retakePhoto,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retake'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Loading Indicator or Nutrition Info
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            )
          else if (_nutritionInfo.isNotEmpty)
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.restaurant, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Nutritional Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        _nutritionInfo,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
