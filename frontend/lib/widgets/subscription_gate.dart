import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../screens/premium/subscriptionpaymentpage.dart';
import '../theme/app_theme.dart';

// Returns the annual price label for the device locale, e.g. "₹199" or "$2.99"
String _localAnnualPrice() {
  const _countryCurrency = <String, String>{
    'IN': 'INR', 'US': 'USD', 'GB': 'GBP', 'AU': 'AUD', 'CA': 'CAD',
    'SG': 'SGD', 'AE': 'AED', 'MY': 'MYR',
    'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'NL': 'EUR',
    'BE': 'EUR', 'AT': 'EUR', 'FI': 'EUR', 'PT': 'EUR', 'IE': 'EUR',
    'GR': 'EUR', 'LU': 'EUR',
  };
  const _display = <String, String>{
    'INR': '₹99', 'USD': r'$1.49', 'EUR': '€1.29', 'GBP': '£0.99',
    'AED': 'AED 4.49', 'SGD': r'S$1.99', 'AUD': r'A$1.99',
    'CAD': r'C$1.99', 'MYR': 'RM 5.99',
  };
  // Prefer timezone-based detection: IST (UTC+5:30 = 330 min) reliably
  // identifies Indian users even when their device locale is set to en_US.
  final tzOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
  if (tzOffsetMinutes == 330) return '₹99';

  final country = PlatformDispatcher.instance.locale.countryCode ?? '';
  final currency = _countryCurrency[country] ?? 'INR';
  return _display[currency] ?? '₹99';
}

// ═══════════════════════════════════════════════════════════════════════════════
// SubscriptionGate
// ═══════════════════════════════════════════════════════════════════════════════

/// Wraps a widget so that when the free trial has expired (and the user is not
/// premium), the [child] is blurred and a paywall lock overlay is rendered on
/// top. During the trial or when premium, the [child] is shown as-is.
class SubscriptionGate extends StatelessWidget {
  const SubscriptionGate({
    super.key,
    required this.child,
    this.featureName = 'this feature',
    this.featureIcon = Icons.lock_outline,
    /// Minimum height for the gated area so the blur/overlay is visible even
    /// when the child is empty (e.g. loading state).
    this.minGatedHeight = 320.0,
  });

  final Widget child;
  final String featureName;
  final IconData featureIcon;
  final double minGatedHeight;

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, subs, _) {
        // While loading, render children normally (avoid flash of locked UI)
        if (subs.isLoading) return child;

        // Premium or trial still active → full access
        if (!subs.shouldGate) return child;

        // Trial expired and not premium → gated
        return _GatedContent(
          child: child,
          featureName: featureName,
          featureIcon: featureIcon,
          minGatedHeight: minGatedHeight,
        );
      },
    );
  }
}

class _GatedContent extends StatelessWidget {
  const _GatedContent({
    required this.child,
    required this.featureName,
    required this.featureIcon,
    required this.minGatedHeight,
  });

  final Widget child;
  final String featureName;
  final IconData featureIcon;
  final double minGatedHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showPaywall(context),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minGatedHeight),
          child: Stack(
            children: [
              // ── Blurred child ──────────────────────────────────────────────
              IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: child,
                ),
              ),

              // ── Semi-transparent overlay ───────────────────────────────────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Colors.black.withOpacity(0.45),
                              Colors.black.withOpacity(0.65),
                            ]
                          : [
                              Colors.white.withOpacity(0.50),
                              Colors.white.withOpacity(0.72),
                            ],
                    ),
                  ),
                ),
              ),

              // ── Lock overlay card ──────────────────────────────────────────
              Positioned.fill(
                child: Center(
                  child: _LockOverlayCard(
                    featureName: featureName,
                    featureIcon: featureIcon,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ChangeNotifierProvider.value(
        value: Provider.of<SubscriptionService>(context, listen: false),
        child: const SubscriptionPaywallModal(),
      ),
    );
  }
}

class _LockOverlayCard extends StatelessWidget {
  const _LockOverlayCard({
    required this.featureName,
    required this.featureIcon,
    required this.isDark,
  });

  final String featureName;
  final IconData featureIcon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock icon with green gradient background
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),

          // Headline
          Text(
            'Free Trial Ended',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Sub-text
          Text(
            'Unlock $featureName and full premium access to keep growing.',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                // Close any bottom sheet first if present, then show paywall
                Navigator.of(context, rootNavigator: true).maybePop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (sheetCtx) => ChangeNotifierProvider.value(
                    value: Provider.of<SubscriptionService>(context, listen: false),
                    child: const SubscriptionPaywallModal(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Unlock Premium — ${_localAnnualPrice()}/yr',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SubscriptionTrialBanner
// ═══════════════════════════════════════════════════════════════════════════════

/// A subtle banner shown during the free trial period.
/// Displays days remaining and a link to the paywall.  Hidden once premium.
class SubscriptionTrialBanner extends StatelessWidget {
  const SubscriptionTrialBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, subs, _) {
        // Only show during active trial
        if (subs.isLoading || !subs.isTrialActive) return const SizedBox.shrink();

        final daysLeft = subs.daysLeft;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetCtx) => ChangeNotifierProvider.value(
              value: Provider.of<SubscriptionService>(context, listen: false),
              child: const SubscriptionPaywallModal(),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppColors.primary.withOpacity(0.22),
                        AppColors.primaryLight.withOpacity(0.12),
                      ]
                    : [
                        AppColors.primary.withOpacity(0.10),
                        AppColors.primaryLight.withOpacity(0.06),
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        daysLeft == 1
                            ? 'Last day of your free trial!'
                            : '$daysLeft days left in your free trial',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A3C2A),
                        ),
                      ),
                      Text(
                        'Tap to explore premium benefits',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.primary
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SubscriptionPaywallModal
// ═══════════════════════════════════════════════════════════════════════════════

/// Full-featured paywall bottom sheet.
/// Shows trial status, feature list, pricing, and CTA to [SubscriptionPaymentPage].
class SubscriptionPaywallModal extends StatelessWidget {
  const SubscriptionPaywallModal({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subs = context.read<SubscriptionService>();
    final daysLeft = subs.daysLeft;
    final isExpired = subs.isTrialExpired;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.55,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F231C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle ──────────────────────────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // ── Hero gradient header ─────────────────────────────────────
                _buildHeader(isDark, isExpired, daysLeft),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Trial status chip ────────────────────────────────
                      _buildStatusChip(isDark, isExpired, daysLeft),
                      const SizedBox(height: 28),

                      // ── Features list ────────────────────────────────────
                      Text(
                        'Everything you get with Premium',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._features.map((f) => _FeatureRow(feature: f, isDark: isDark)),
                      const SizedBox(height: 28),

                      // ── Price card ───────────────────────────────────────
                      _buildPriceCard(isDark),
                      const SizedBox(height: 24),

                      // ── CTA button ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SubscriptionPaymentPage(),
                              ),
                            ).then((_) {
                              // Use singleton to refresh — avoids stale context
                              // after modal was already dismissed via pop().
                              SubscriptionService().refresh();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Start Premium — ${_localAnnualPrice()} / year',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Maybe later ──────────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Maybe later',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),

                      // ── Fine print ───────────────────────────────────────
                      Center(
                        child: Text(
                          'Cancel anytime · Secure payment via Razorpay',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, bool isExpired, int daysLeft) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF1B8A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Logo mark
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),

          Text(
            'Livegreen Premium',
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isExpired
                ? 'Your 42-day free trial has ended'
                : 'Your free trial · $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isDark, bool isExpired, int daysLeft) {
    final color = isExpired ? Colors.red.shade600 : AppColors.primary;
    final bgColor = isExpired
        ? Colors.red.shade50
        : AppColors.primary.withOpacity(0.08);
    final icon = isExpired ? Icons.timer_off_rounded : Icons.timer_rounded;
    final label = isExpired
        ? 'Free trial ended — subscribe to continue'
        : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} remaining in your free trial';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? color.withOpacity(0.9) : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primary.withOpacity(0.18),
                  AppColors.primary.withOpacity(0.08),
                ]
              : [
                  AppColors.primary.withOpacity(0.07),
                  AppColors.primaryLight.withOpacity(0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.28),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annual Plan',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Full premium access · Cancel anytime',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _localAnnualPrice(),
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -1,
                ),
              ),
              Text(
                '/ year',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<_PremiumFeature> _features = [
    _PremiumFeature(
      icon: Icons.explore_rounded,
      color: Color(0xFFFF9800),
      title: 'Nature Explorer Activities',
      subtitle: 'Eco-treks, outdoor quests and nature discovery',
    ),
    _PremiumFeature(
      icon: Icons.restaurant_menu_rounded,
      color: Color(0xFF00A859),
      title: 'Nutrition & Diet Activities',
      subtitle: 'Personalised meal plans and diet challenges',
    ),
    _PremiumFeature(
      icon: Icons.groups_rounded,
      color: Color(0xFF4FACFE),
      title: 'Clubs & Community',
      subtitle: 'Join local eco-clubs and connect with members',
    ),
    _PremiumFeature(
      icon: Icons.watch_outlined,
      color: Color(0xFF9C27B0),
      title: 'Health Connect & Wearables',
      subtitle: 'Sync Fitbit, Samsung Health, Google Fit and more',
    ),
    _PremiumFeature(
      icon: Icons.all_inclusive_rounded,
      color: Color(0xFFE91E63),
      title: 'All Future Premium Features',
      subtitle: 'Early access to every new premium addition',
    ),
  ];
}

class _PremiumFeature {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _PremiumFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.isDark});
  final _PremiumFeature feature;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  feature.subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }
}
