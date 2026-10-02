import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether this device has ever completed a successful login, so the
/// onboarding carousel can be skipped once that happens.
class OnboardingPrefsService {
  const OnboardingPrefsService();

  static const String _hasLoggedInKey = 'has_logged_in_before';

  Future<bool> hasLoggedInBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasLoggedInKey) ?? false;
  }

  Future<void> markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasLoggedInKey, true);
  }
}
