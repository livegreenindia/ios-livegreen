import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Privacy Policy screen displaying app privacy information.
/// This is required for Play Store submission.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGreen = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(isDark),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'LiveGreen ("we", "our", or "us") is committed to protecting your privacy. '
              'This Privacy Policy explains how we collect, use, disclose, and safeguard your '
              'information when you use our mobile application.',
              isDark,
            ),
            _buildSection(
              'Information We Collect',
              '''We may collect information about you in a variety of ways:

• Personal Data: Name, email address, and profile information you provide when creating an account.

• Usage Data: Information about your activity completions, wellness preferences, and app interactions.

• Device Data: Device type, operating system, and unique device identifiers.

• Health & Wellness Data: Social media usage patterns (with your permission), activity tracking data, and wellness goals you set.

• Location Data: We do not collect precise location data.''',
              isDark,
            ),
            _buildSection(
              'How We Use Your Information',
              '''We use the information we collect to:

• Provide, maintain, and improve our services
• Personalize your wellness experience
• Send you activity reminders and notifications
• Track your progress toward sustainability goals
• Communicate with you about updates and features
• Analyze usage patterns to improve the app''',
              isDark,
            ),
            _buildSection(
              'Data Storage & Security',
              'Your data is stored securely using Firebase services with industry-standard encryption. '
              'We implement appropriate technical and organizational measures to protect your personal information.',
              isDark,
            ),
            _buildSection(
              'Third-Party Services',
              '''We use the following third-party services:

• Firebase (Google) - Authentication, database, and analytics
• Razorpay - Payment processing for premium features
• Fitbit - Health data integration (optional)

Each service has its own privacy policy governing the use of your information.''',
              isDark,
            ),
            _buildSection(
              'Your Rights',
              '''You have the right to:

• Access your personal data
• Correct inaccurate data
• Delete your account and associated data
• Export your data
• Opt-out of marketing communications
• Withdraw consent for data processing''',
              isDark,
            ),
            _buildSection(
              'Data Retention',
              'We retain your personal data for as long as your account is active or as needed to provide you services. '
              'You can request deletion of your data at any time by contacting us or using the in-app account deletion feature.',
              isDark,
            ),
            _buildSection(
              'Children\'s Privacy',
              'Our service is not intended for children under 13 years of age. '
              'We do not knowingly collect personal information from children under 13.',
              isDark,
            ),
            _buildSection(
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes '
              'by posting the new Privacy Policy on this page and updating the "Last Updated" date.',
              isDark,
            ),
            _buildSection(
              'Contact Us',
              '''If you have questions about this Privacy Policy, please contact us at:

Email: support@livegreen.app''',
              isDark,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.update,
            size: 16,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            'Last Updated: November 26, 2025',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
