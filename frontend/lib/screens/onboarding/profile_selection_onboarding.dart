import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';

/// Onboarding screen for selecting wellness profile
/// This is shown immediately after signup/login if user hasn't selected a profile
class ProfileSelectionOnboarding extends StatefulWidget {
  const ProfileSelectionOnboarding({super.key});

  @override
  State<ProfileSelectionOnboarding> createState() => _ProfileSelectionOnboardingState();
}

class _ProfileSelectionOnboardingState extends State<ProfileSelectionOnboarding> {
  String? _selectedProfile;
  bool _loading = false;

  final Map<String, ProfileData> _profiles = {
    'Working': ProfileData(
      icon: Icons.business_center,
      color: AppColors.primary,
      description: 'For professionals balancing work and wellness',
      gradient: [AppColors.primary, const Color(0xFF02C077)],
    ),
    'Student': ProfileData(
      icon: Icons.school,
      color: const Color(0xFF2196F3),
      description: 'For students managing studies and health',
      gradient: [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
    ),
    'Housewife': ProfileData(
      icon: Icons.home,
      color: const Color(0xFFE91E63),
      description: 'For homemakers prioritizing family wellness',
      gradient: [const Color(0xFFE91E63), const Color(0xFFF06292)],
    ),
    'Retired': ProfileData(
      icon: Icons.deck,
      color: const Color(0xFFFF9800),
      description: 'For retirees enjoying active lifestyle',
      gradient: [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
    ),
  };

  Future<void> _saveProfile() async {
    if (_selectedProfile == null) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'wellness_profile': _selectedProfile,
          'profile_updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profile saved successfully. Welcome to LiveGreen!',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate to home
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to save profile. Please try again.',
                  style: GoogleFonts.manrope(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Welcome header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    const Color(0xFF02C077).withOpacity(0.1),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 60,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Welcome to LiveGreen',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Let\'s personalize your wellness journey',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Section title
                      Text(
                        'What describes you best?',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your lifestyle to get personalized activities',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Profile cards
                      ..._profiles.entries.map((entry) => _buildProfileCard(
                            entry.key,
                            entry.value,
                          )),
                    ],
                  ),
                ),
              ),

              // Bottom action button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedProfile != null
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      elevation: _selectedProfile != null ? 2 : 0,
                    ),
                    onPressed: _selectedProfile == null || _loading
                        ? null
                        : _saveProfile,
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Continue to LiveGreen',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedProfile != null
                                  ? Colors.white
                                  : Colors.grey.shade500,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, ProfileData data) {
    final isSelected = _selectedProfile == name;

    return GestureDetector(
      onTap: () => setState(() => _selectedProfile = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: data.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: data.color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : data.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                data.icon,
                size: 32,
                color: isSelected ? Colors.white : data.color,
              ),
            ),

            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Check icon
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 20,
                  color: data.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileData {
  final IconData icon;
  final Color color;
  final String description;
  final List<Color> gradient;

  ProfileData({
    required this.icon,
    required this.color,
    required this.description,
    required this.gradient,
  });
}
