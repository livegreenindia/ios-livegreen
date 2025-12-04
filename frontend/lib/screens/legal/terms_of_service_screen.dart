import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Terms of Service screen displaying app usage terms.
/// This is required for Play Store submission.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGreen = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              'Agreement to Terms',
              'By accessing or using LiveGreen, you agree to be bound by these Terms of Service. '
              'If you do not agree to these terms, please do not use our application.',
              isDark,
            ),
            _buildSection(
              'Description of Service',
              'LiveGreen is a wellness and sustainability application that helps users track their daily activities, '
              'reduce screen time, and develop healthier habits. Our services include activity tracking, progress visualization, '
              'community forums, and premium features.',
              isDark,
            ),
            _buildSection(
              'User Accounts',
              '''To use certain features of LiveGreen, you must create an account. You agree to:

• Provide accurate and complete information
• Maintain the security of your account credentials
• Notify us immediately of any unauthorized access
• Accept responsibility for all activities under your account

We reserve the right to suspend or terminate accounts that violate these terms.''',
              isDark,
            ),
            _buildSection(
              'Acceptable Use',
              '''You agree NOT to:

• Use the app for any illegal purpose
• Harass, abuse, or harm other users
• Post inappropriate or offensive content in forums
• Attempt to gain unauthorized access to our systems
• Interfere with or disrupt the service
• Use automated systems to access the service
• Impersonate others or provide false information
• Violate any applicable laws or regulations''',
              isDark,
            ),
            _buildSection(
              'User Content',
              'You retain ownership of content you post (such as forum posts). By posting content, '
              'you grant us a non-exclusive, royalty-free license to use, display, and distribute your content '
              'within the app. You are responsible for ensuring your content does not violate any laws or third-party rights.',
              isDark,
            ),
            _buildSection(
              'Premium Subscriptions',
              '''Premium features are available through paid subscriptions:

• Payments are processed securely through Razorpay
• Subscriptions auto-renew unless cancelled
• Refunds are subject to our refund policy
• Prices may change with notice
• Premium features may be modified over time

Cancel your subscription at any time through the app settings.''',
              isDark,
            ),
            _buildSection(
              'Intellectual Property',
              'The LiveGreen app, including its design, features, and content, is protected by copyright, '
              'trademark, and other intellectual property laws. You may not copy, modify, distribute, or '
              'create derivative works without our written permission.',
              isDark,
            ),
            _buildSection(
              'Health Disclaimer',
              '''IMPORTANT: LiveGreen is not a medical device or healthcare provider.

• The app provides general wellness information only
• Do not use this app as a substitute for professional medical advice
• Consult a healthcare provider before making health decisions
• We are not liable for any health outcomes from using this app
• Activity recommendations are suggestions, not medical prescriptions''',
              isDark,
            ),
            _buildSection(
              'Limitation of Liability',
              '''To the maximum extent permitted by law:

• The app is provided "as is" without warranties
• We do not guarantee uninterrupted or error-free service
• We are not liable for any indirect, incidental, or consequential damages
• Our total liability is limited to the amount you paid for premium services
• We are not responsible for third-party services or content''',
              isDark,
            ),
            _buildSection(
              'Indemnification',
              'You agree to indemnify and hold harmless LiveGreen and its affiliates from any claims, '
              'damages, or expenses arising from your use of the app or violation of these terms.',
              isDark,
            ),
            _buildSection(
              'Modifications to Service',
              'We reserve the right to modify, suspend, or discontinue any part of the service at any time. '
              'We will provide notice of significant changes when possible.',
              isDark,
            ),
            _buildSection(
              'Changes to Terms',
              'We may update these Terms of Service from time to time. Continued use of the app after '
              'changes constitutes acceptance of the new terms. We will notify you of material changes.',
              isDark,
            ),
            _buildSection(
              'Governing Law',
              'These terms are governed by the laws of India. Any disputes will be resolved in the courts '
              'of [Your Jurisdiction], and you consent to the personal jurisdiction of such courts.',
              isDark,
            ),
            _buildSection(
              'Contact Information',
              '''For questions about these Terms of Service:

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
