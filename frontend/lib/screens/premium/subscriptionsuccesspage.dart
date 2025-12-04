import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class SubscriptionSuccessPage extends StatelessWidget {
  const SubscriptionSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              
              // Success Title
              Text(
                'Payment Successful!',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Success Message
              Text(
                'You are now a premium member',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                'Enjoy exclusive features and benefits',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Premium Benefits
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Benefits',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _benefitRow(Icons.check_circle_outline, 'Ad-free experience', isDark),
                    _benefitRow(Icons.fitness_center, 'Advanced fitness tracking', isDark),
                    _benefitRow(Icons.insights, 'Detailed analytics', isDark),
                    _benefitRow(Icons.groups, 'Priority support', isDark),
                    _benefitRow(Icons.stars, 'Exclusive content', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Back to Home Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Navigate back to home, removing all previous routes
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Continue to App',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
