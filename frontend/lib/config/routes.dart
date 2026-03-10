import 'package:flutter/material.dart';
import '../screens/auth/login.dart';
import '../screens/pages/home.dart';
import '../screens/auth/signup.dart';
import '../screens/pages/progress.dart';
import '../screens/pages/community.dart';
import '../screens/pages/profile.dart';
import '../screens/pages/activity.dart';
import '../screens/health_connect_screen.dart';
import '../screens/profile_selection_screen.dart';
import '../screens/wellness_schedule_screen.dart';
import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_of_service_screen.dart';
import '../screens/trek/trek_list_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const signup = '/signup';
  static const progress = '/progress';
  static const community = '/community';
  static const profile = '/profile';
  static const healthConnect = '/health-connect';
  static const activity = '/activity';
  static const profileSelection = '/wellness/profile-selection';
  static const wellnessSchedule = '/wellness/schedule';
  static const privacyPolicy = '/legal/privacy-policy';
  static const termsOfService = '/legal/terms-of-service';
  static const trekExplorer = '/trek-explorer';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case activity:
        return MaterialPageRoute(builder: (_) => const ActivityPage());
      case progress:
        return MaterialPageRoute(builder: (_) => const ProgressPage());
      case community:
        return MaterialPageRoute(builder: (_) => const CommunityPage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case healthConnect:
        final uid = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => HealthConnectScreen(uid: uid));
      case profileSelection:
        return MaterialPageRoute(builder: (_) => const ProfileSelectionScreen());
      case wellnessSchedule:
        final profile = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => WellnessScheduleScreen(profile: profile ?? 'Work'),
        );
      case privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());
      case termsOfService:
        return MaterialPageRoute(builder: (_) => const TermsOfServiceScreen());
      case trekExplorer:
        return MaterialPageRoute(builder: (_) => const TrekListScreen());
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
