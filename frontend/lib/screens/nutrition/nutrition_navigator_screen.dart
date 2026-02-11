import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/user_profile.dart';
import '../home_screen.dart';
import '../history_page.dart';
import '../camera_page.dart';
import '../profile_setup_page.dart';

class NutritionNavigatorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final UserProfile profile;

  const NutritionNavigatorScreen({
    Key? key,
    required this.cameras,
    required this.profile,
  }) : super(key: key);

  @override
  State<NutritionNavigatorScreen> createState() =>
      _NutritionNavigatorScreenState();
}

class _NutritionNavigatorScreenState extends State<NutritionNavigatorScreen> {
  int _currentIndex = 1; // Start with Home tab
  UserProfile? _profile;
  final GlobalKey<State> _historyPageKey = GlobalKey<State>();

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _updateProfile() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSetupPage(
          cameras: widget.cameras,
          existingProfile: _profile,
          onProfileSaved: (updatedProfile) async {
            print(
                'NutritionNavigatorScreen: Profile updated from ${_profile?.weight}kg to ${updatedProfile.weight}kg');
            print(
                'Health conditions updated: ${_profile?.healthConditions} -> ${updatedProfile.healthConditions}');

            // Save updated profile
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                'user_profile', json.encode(updatedProfile.toJson()));

            setState(() {
              _profile = updatedProfile;
            });

            // Navigate back with updated profile
            Navigator.of(context).pop();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Profile updated successfully! Nutrient requirements recalculated.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onFoodAnalyzed(String nutritionInfo) {
    print('NutritionNavigatorScreen: Food analyzed callback received');

    // Switch to history tab to show the updated data
    setState(() {
      _currentIndex = 2; // History tab
    });

    // Refresh history page if it has a refresh method
    if (_historyPageKey.currentState != null) {
      final historyState = _historyPageKey.currentState;
      if (historyState is State) {
        // Call refresh if the state has that method
        try {
          (historyState as dynamic).refreshData();
        } catch (e) {
          print('Could not call refreshData: $e');
        }
      }
    }
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0: // Camera
        return CameraPage(
          cameras: widget.cameras,
          apiKey: 'AIzaSyCEU91Yy27b0VqBw95THdGpVlm-Oqu6eT0',
          userProfile: _profile,
          onFoodAnalyzed: _onFoodAnalyzed,
          onClose: () {
            // Switch to Home tab when camera is closed
            setState(() {
              _currentIndex = 1;
            });
          },
        );
      case 1: // Home
        return HomeScreen(
          cameras: widget.cameras,
          profile: _profile!,
          onProfileUpdated: (updatedProfile) async {
            // Save updated profile and refresh state
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                'user_profile', json.encode(updatedProfile.toJson()));
            setState(() {
              _profile = updatedProfile;
            });
          },
        );
      case 2: // History
        return HistoryPage(
          key: _historyPageKey,
          profile: _profile!,
          cameras: widget.cameras,
          onRefresh: () {
            // Refresh callback if needed
            setState(() {});
          },
        );
      default:
        return HomeScreen(
          cameras: widget.cameras,
          profile: _profile!,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
