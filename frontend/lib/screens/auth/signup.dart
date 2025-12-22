import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// Check if user has wellness profile and navigate accordingly
  Future<void> _checkProfileAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Clear activity completions for new users
      await CompletionStore.clearAll();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final hasProfile = doc.exists && doc.data()?['wellness_profile'] != null;
      
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
            children: [
              // Scrollable Banner Image
              Image.network(
                "https://lh3.googleusercontent.com/aida-public/AB6AXuD9qjk1riHArzwwlTWYeNyZYpp_ovT1UZYW3PvHK4YYangVlRLzRmKTFsefac1OfHiR5ArbZjS41EtXsCyXVj1fx_-kFWlJP2KmNJPGh2WqI5XI6nokwNqF167nxu4VihNE-lzc0CxOlSFS1J0vRIce57iaCpfQUXgBkylxveRdy16d1T5GYYUdi-3Z8x7Sy38BZeZaoQ1tIyzB-a0EXq52J5WJ0XnMaH1vk2RE1XhoaHRnxZI51KQInsAU3x2qle9frs_03mTxjC0",
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title & subtitle
                    Text(
                      "Create an Account",
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Join LiveGreen to start your journey.",
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Name
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: "Name",
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "Email",
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: "Password",
                        prefixIcon: Icon(
                          Icons.lock_outlined,
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: "Confirm Password",
                        prefixIcon: Icon(
                          Icons.lock_outlined,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: _loading
                              ? null
                              : () async {
                                final name = _nameController.text.trim();
                                final email = _emailController.text.trim();
                                final pass = _passwordController.text;
                                final confirm = _confirmController.text;
                                
                                // Validate name
                                final nameError = ErrorHandler.validateName(name);
                                if (nameError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(nameError)),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                  return;
                                }
                                
                                // Validate email
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
                                      backgroundColor: Colors.orange.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                  return;
                                }
                                
                                // Validate password
                                final passError = ErrorHandler.validatePassword(pass);
                                if (passError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(passError)),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                  return;
                                }
                                
                                // Validate password match
                                final matchError = ErrorHandler.validatePasswordMatch(pass, confirm);
                                if (matchError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(matchError)),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                  return;
                                }
                                
                                setState(() => _loading = true);
                                try {
                                  final userCredential = await AuthService().signUpWithEmail(email: email, password: pass);
                                  
                                  // Send email verification
                                  await AuthService().sendEmailVerification();
                                  
                                  // Save display name
                                  if (name.isNotEmpty) {
                                    try { 
                                      await AuthService().updateDisplayName(name); 
                                    } catch (_) { /* ignore */ }
                                  }
                                  
                                  if (!context.mounted) return;
                                  
                                  // Show verification required message
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Email Verification Required'),
                                      content: Text(
                                        'We\'ve sent a verification email to $email. '
                                        'Please check your email and click the verification link before signing in.'
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(); // Close dialog
                                            Navigator.of(context).pushReplacementNamed('/login'); // Go to login
                                          },
                                          child: const Text('Go to Login'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            // Resend verification email
                                            try {
                                              await AuthService().sendEmailVerification();
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Verification email sent again'),
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
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primaryLight, AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(80),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "Sign Up",
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // OR divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            thickness: 1,
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
                            Navigator.of(context).pop();
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
                              child: Text(
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
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Sign up with Google",
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

                    // Already have account? Login
                    Text.rich(
                      TextSpan(
                        text: "Already have an account? ",
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        children: [
                          TextSpan(
                            text: "Log in",
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, AppRoutes.login);
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
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
