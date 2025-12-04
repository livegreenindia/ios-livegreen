import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';
import 'pages/welcome.dart';
import '../screens/auth/login.dart';
import '../../config/routes.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _showSplash = true;
  bool? _seenOnboarding;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool("seenOnboarding") ?? false;
    final current = FirebaseAuth.instance.currentUser;
    
    if (mounted) {
      setState(() {
        _seenOnboarding = seen;
        _isLoggedIn = current != null;
      });
    }
  }

  void _onSplashComplete() {
    if (!mounted) return;
    
    if (_isLoggedIn) {
      // Directly navigate to home replacing the stack
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show animated splash screen first
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // After splash, show appropriate screen
    if (_seenOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _seenOnboarding! ? const LoginScreen() : const WelcomePage();
  }
}
