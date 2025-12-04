import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api.dart';
import '../../config/api.dart' as cfg;
import '../../theme/app_theme.dart';
import 'subscriptionsuccesspage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  final bool isDonation;
  
  const SubscriptionPaymentPage({super.key, this.isDonation = false});

  @override
  State<SubscriptionPaymentPage> createState() =>
      _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> 
    with WidgetsBindingObserver {
  // Theme-aware color getters
  Color get primaryColor => AppColors.primary;
  Color get backgroundLight => AppColors.backgroundLight;
  Color get backgroundDark => AppColors.backgroundDark;

  final double _amount = 199.0;
  bool _loading = false;
  String? _error;
  String? _errorDetails;
  bool _showDetails = false;
  Razorpay? _razorpay;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize Razorpay SDK only when needed (i.e., not using external link)
    if (!(widget.isDonation && cfg.razorpayPaymentLink.isNotEmpty)) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _razorpay?.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app returning from background (e.g., from external payment app)
    if (state == AppLifecycleState.resumed && _isProcessingPayment) {
      // App resumed but we're still processing payment
      // Keep loading state - Razorpay will trigger success/error callback
      debugPrint('[Payment] App resumed while processing payment - waiting for callback');
    }
  }

  Future<void> _openDonationLink() async {
    final link = cfg.razorpayPaymentLink.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation link not configured')), 
      );
      return;
    }
    final uri = Uri.parse(link);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Could not launch donation link');
      }
      // No local premium toggles for donations; handled by webhook/backoffice.
      setState(() { _loading = false; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not open donation link';
        _errorDetails = e.toString();
      });
    }
  }

  Future<void> _startRazorpayPayment() async {
    setState(() {
      _loading = true;
      _error = null;
      _isProcessingPayment = true; // Mark that payment is in progress
    });

    try {
      // Ensure user is signed in before creating an order. Backend requires
      // a valid Firebase ID token (Authorization: Bearer <idToken>).
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'You must be signed in to make payments.';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to continue')),
        );
        return;
      }
      final api = ApiService(baseUrl: cfg.apiBaseUrl);

      // 1. Create Razorpay order via backend
      final resp = await api.createRazorpayOrder(_amount);
      final orderId = resp['orderId'] as String?;
      final key = resp['key'] as String? ?? cfg.razorpayPublicKey;

      if (orderId == null) {
        throw Exception('Invalid Razorpay order response from backend');
      }

      // 2. Open Razorpay checkout
      // Attempt to prefill user details from Firebase Auth if available.
      String prefillEmail = '';
      String prefillContact = '';
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          prefillEmail = user.email ?? '';
          prefillContact = user.phoneNumber ?? '';
        }
      } catch (e) {
        // Avoid crashing if FirebaseAuth hasn't been initialized in some test harnesses.
        debugPrint('Unable to read FirebaseAuth.currentUser for prefill: $e');
      }

      final options = {
        'key': key,
        'amount': (_amount * 100).toInt(), // in paise
        'currency': 'INR',
        'name': 'Livegreen',
        'description': widget.isDonation ? 'Support Contribution' : 'Premium Subscription',
        'order_id': orderId,
        'prefill': {
          'email': prefillEmail,
          'contact': prefillContact,
        },
        // Configure payment methods
        'method': {
          'upi': true,
          'card': true,
          'wallet': true,
          'netbanking': true,
        },
        // Callback URL for handling external wallet redirects
        'callback_url': '',
        'redirect': true,
        // Modal settings
        'modal': {
          'ondismiss': () {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
          'escape': true,
          'animation': true,
        },
        'theme': {'color': '#38e07b'},
        // Add retry configuration
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        // Timeout for payment completion (in seconds)
        'timeout': 600, // 10 minutes
      };

      _razorpay!.open(options);
    } catch (e) {
      setState(() {
        _loading = false;
        _isProcessingPayment = false;
        // Friendly short message for UI, keep raw details separately
        _error = 'Payment initialization failed. Tap "Show details" for more.';
        _errorDetails = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment initialization failed')),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final api = ApiService(baseUrl: cfg.apiBaseUrl);
      // 3. Verify payment signature with backend - MUST succeed before marking premium
      await api.verifyRazorpayPayment(
        response.orderId!,
        response.paymentId!,
        response.signature!,
      );

      // Only mark premium locally AFTER successful verification
      // This ensures UI only shows premium status when payment is actually verified
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_premium', true);
      } catch (e) {
        // ignore shared prefs errors
        debugPrint('Failed to persist local premium flag: $e');
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _isProcessingPayment = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionSuccessPage()),
        );
      }
    } catch (e) {
      // Payment verification FAILED - do NOT mark as premium
      // Clear any existing premium flag to ensure UI shows correct state
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_premium', false);
      } catch (_) {}
      
      setState(() {
        _loading = false;
        _isProcessingPayment = false;
        _error = 'Payment verification failed. Tap "Show details" for more.';
        _errorDetails = e.toString();
      });
      
      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed. Please contact support if amount was deducted.'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _loading = false;
      _isProcessingPayment = false;
      
      // Check if user cancelled the payment
      if (response.code == Razorpay.PAYMENT_CANCELLED) {
        _error = 'Payment cancelled';
        _errorDetails = 'You cancelled the payment process';
      } else {
        _error = 'Payment failed: ${response.message ?? response.code.toString()}';
        _errorDetails = 'Code: ${response.code}\nMessage: ${response.message}';
      }
    });
    
    // Show appropriate message
    if (mounted) {
      final message = response.code == Razorpay.PAYMENT_CANCELLED 
          ? 'Payment cancelled by user'
          : 'Payment failed: ${response.message ?? 'Unknown error'}';
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: response.code == Razorpay.PAYMENT_CANCELLED 
              ? Colors.orange 
              : Colors.red,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallet selected (PhonePe, Google Pay, etc.)
    // Keep loading state - payment will complete via success/error callback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${response.walletName ?? 'payment app'}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    // Don't set _loading = false here - wait for actual payment result
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? backgroundDark : backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isDonation ? "Support LiveGreen" : "Subscription Payment",
          style: GoogleFonts.manrope(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isDonation 
                    ? "Thank you for supporting us! 💚" 
                    : "Confirm Your Subscription",
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _priceCard(isDark),
              const SizedBox(height: 30),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: GoogleFonts.manrope(color: Colors.redAccent),
                ),
                const SizedBox(height: 8),
                if (_errorDetails != null) ...[
                  TextButton(
                    onPressed: () => setState(() => _showDetails = !_showDetails),
                    child: Text(_showDetails ? 'Hide details' : 'Show details'),
                  ),
                  if (_showDetails)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          _errorDetails!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                ],
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading
                    ? null
                    : () async {
                        if (widget.isDonation && cfg.razorpayPaymentLink.isNotEmpty) {
                          await _openDonationLink();
                        } else {
                          await _startRazorpayPayment();
                        }
                      },
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.isDonation ? "Donate ₹${_amount.toInt()}" : "Pay ₹${_amount.toInt()}",
                        style: GoogleFonts.manrope(
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

  Widget _priceCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _priceRow("Type", widget.isDonation ? "Donation 💚" : "Premium"),
          const SizedBox(height: 10),
          if (!widget.isDonation) ...[
            _priceRow("Duration", "1 Year"),
            const SizedBox(height: 10),
          ],
          _priceRow("Amount", "₹199"),
          const Divider(height: 30, thickness: 1),
          _priceRow("Total", "₹199", isTotal: true),
          if (widget.isDonation) ...[
            const SizedBox(height: 16),
            Text(
              "Your contribution helps us keep all features free for everyone!",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: primaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? primaryColor : null,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? primaryColor : null,
          ),
        ),
      ],
    );
  }
}
