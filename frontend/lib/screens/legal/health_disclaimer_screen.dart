import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Health Disclaimer screen.
/// Displayed during onboarding and accessible from the profile legal section.
/// Required by Google Play Health Content and Services policy.
class HealthDisclaimerScreen extends StatelessWidget {
  /// When [showAcknowledgeButton] is true, a prominent "I Understand" button is
  /// shown. Pass [onAcknowledge] to handle the tap (e.g. navigate to login).
  final bool showAcknowledgeButton;
  final VoidCallback? onAcknowledge;

  const HealthDisclaimerScreen({
    super.key,
    this.showAcknowledgeButton = false,
    this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGreen = AppColors.primary;

    return Scaffold(
      appBar: showAcknowledgeButton
          ? null
          : AppBar(
              title: const Text('Health Disclaimer'),
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.health_and_safety_outlined,
                        size: 56,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Health Disclaimer',
                      style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Main disclaimer box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.shade300,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'NOT A MEDICAL DEVICE',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange.shade800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'LiveGreen is a general wellness and lifestyle app. It is NOT a medical device and is NOT intended to diagnose, treat, cure, or prevent any disease or medical condition.',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        height: 1.55,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildPoint(
                icon: Icons.person_search_outlined,
                title: 'For Informational Purposes Only',
                body:
                    'All activity tracking, step counts, calorie estimates, and wellness content provided by this app are for general informational and motivational purposes only.',
                isDark: isDark,
              ),
              _buildPoint(
                icon: Icons.medical_services_outlined,
                title: 'Not a Substitute for Professional Advice',
                body:
                    'Nothing in this app constitutes medical advice, diagnosis, or treatment. Always seek the advice of a qualified healthcare provider before starting any exercise, diet, or wellness program — especially if you have a pre-existing medical condition.',
                isDark: isDark,
              ),
              _buildPoint(
                icon: Icons.emergency_outlined,
                title: 'Emergency Situations',
                body:
                    'This app is not designed for emergency use. If you are experiencing a medical emergency, call your local emergency services immediately.',
                isDark: isDark,
              ),
              _buildPoint(
                icon: Icons.tune_outlined,
                title: 'Individual Results May Vary',
                body:
                    'Wellness recommendations within the app are general suggestions only. Results vary by individual and are not guaranteed. The developers of LiveGreen are not liable for any health outcomes arising from use of this app.',
                isDark: isDark,
              ),

              const SizedBox(height: 32),

              if (showAcknowledgeButton) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onAcknowledge,
                    child: Text(
                      'I Understand — Continue',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoint({
    required IconData icon,
    required String title,
    required String body,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
