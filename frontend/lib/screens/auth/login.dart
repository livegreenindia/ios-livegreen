import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../services/completion_store.dart';
import '../../services/location_prefetch_service.dart';
import '../../utils/error_handler.dart';
import '../../theme/app_theme.dart';
import '../onboarding/profile_selection_onboarding.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  /// Check if user has wellness profile and navigate accordingly
  Future<void> _checkProfileAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final hasProfile = doc.exists && doc.data()?['wellness_profile'] != null;
      
      // Clear old activity completions for new users
      if (!doc.exists) {
        await CompletionStore.clearAll();
      }
      
      if (hasProfile) {
        // User has profile, request basic location permission and go to home
        await LocationPrefetchService.requestBasicPermission(context);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        // No profile, show onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSelectionOnboarding(),
          ),
        );
      }
    } catch (e) {
      // On error, just navigate to home
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top banner image
              Image.network(
                "https://lh3.googleusercontent.com/aida-public/AB6AXuD9qjk1riHArzwwlTWYeNyZYpp_ovT1UZYW3PvHK4YYangVlRLzRmKTFsefac1OfHiR5ArbZjS41EtXsCyXVj1fx_-kFWlJP2KmNJPGh2WqI5XI6nokwNqF167nxu4VihNE-lzc0CxOlSFS1J0vRIce57iaCpfQUXgBkylxveRdy16d1T5GYYUdi-3Z8x7Sy38BZeZaoQ1tIyzB-a0EXq52J5WJ0XnMaH1vk2RE1XhoaHRnxZI51KQInsAU3x2qle9frs_03mTxjC0",
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      "Welcome to LiveGreen",
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Log in or create an account to continue.",
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Email field with icon
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: "Email address",
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field with toggle visibility
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: "Password",
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,     
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Forgot password / Resend verification row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _loading ? null : () async {
                            final email = _emailController.text.trim();
                            final emailError = ErrorHandler.validateEmail(email);
                            if (emailError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.white),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Text('Please enter your email address first')),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                ),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              await AuthService().sendEmailVerification();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('Verification email sent!')),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text('Failed to send verification email: $e')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                          child: Text(
                            "Resend Verification",
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : () async {
                            final email = _emailController.text.trim();
                            final emailError = ErrorHandler.validateEmail(email);
                            if (emailError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.white),
                                      const SizedBox(width: 12),
                                      const Expanded(child: Text('Please enter your email address first')),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                ),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              await AuthService().sendPasswordReset(email: email);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('Password reset email sent. Please check your inbox.')),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              final errorMessage = ErrorHandler.getAuthErrorMessage(e);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(errorMessage)),
                                    ],
                                  ),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),                    const SizedBox(height: 16),

                    // Login button with gradient
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _loading 
                            ? [Colors.grey.shade400, Colors.grey.shade500]
                            : [AppColors.primary, const Color(0xFF02C077)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: _loading ? [] : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _loading ? null : () async {
                                final email = _emailController.text.trim();
                                final pass = _passwordController.text;
                                
                                // Validate inputs
                                final emailError = ErrorHandler.validateEmail(email);
                                if (emailError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(emailError)),
                                        ],
                                      ),
                                      backgroundColor: AppColors.warning,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                    ),
                                  );
                                  return;
                                }
                                
                                if (pass.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.white),
                                          SizedBox(width: 12),
                                          Expanded(child: Text('Please enter your password')),
                                        ],
                                      ),
                                      backgroundColor: AppColors.warning,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                    ),
                                  );
                                  return;
                                }
                                
                                setState(() => _loading = true);
                                try {
                                  // Sign in with email and password
                                  final userCredential = await AuthService().signInWithEmail(email: email, password: pass);
                                  
                                  // Check if email is verified
                                  final isVerified = await AuthService().isEmailVerified();
                                  
                                  if (!isVerified) {
                                    if (!context.mounted) return;
                                    
                                    // Show email verification required dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Email Verification Required'),
                                        content: Text(
                                          'Please verify your email address before signing in. '
                                          'Check your email ($email) for the verification link.'
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop(); // Close dialog
                                              // Sign out the user since they can't proceed
                                              AuthService().signOut();
                                            },
                                            child: const Text('OK'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              // Resend verification email
                                              try {
                                                await AuthService().sendEmailVerification();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Verification email sent'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Failed to resend: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('Resend Email'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  // Email is verified, proceed with navigation
                                  if (!context.mounted) return;
                                  await _checkProfileAndNavigate();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  final errorMessage = ErrorHandler.getAuthErrorMessage(e);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(errorMessage)),
                                        ],
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Center(
                            child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Log In",
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // OR divider with enhanced styling
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "OR",
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Google Sign-In button (follows Google brand guidelines)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.surfaceDark
                              : Colors.white,
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator()),
                          );
                          try {
                            await AuthService().signInWithGoogle();
                            if (!context.mounted) return;
                            Navigator.of(context).pop(); // remove loading
                            await _checkProfileAndNavigate();
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            final errorMessage = ErrorHandler.getAuthErrorMessage(e);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(errorMessage)),
                                  ],
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google 'G' logo representation
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                children: [
                                  Text(
                                    'G',
                                    style: GoogleFonts.roboto(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      foreground: Paint()
                                        ..shader = const LinearGradient(
                                          colors: [
                                            Color(0xFF4285F4), // Blue
                                            Color(0xFF34A853), // Green
                                            Color(0xFFFBBC05), // Yellow
                                            Color(0xFFEA4335), // Red
                                          ],
                                        ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Continue with Google",
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Signup link
                    Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        children: [
                          TextSpan(
                            text: "Sign up",
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.signup,
                                ); // 🔁 <-- Make sure this route exists
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
