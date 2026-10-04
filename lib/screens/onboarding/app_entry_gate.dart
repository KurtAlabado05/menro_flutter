import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/onboarding_prefs_service.dart';
import '../../widgets/app_brand_logos.dart';
import '../auth/login_screen.dart';
import '../auth/role_home.dart';
import 'onboarding_screen.dart';

/// Decides once, at startup, where the app opens: the role's home for a
/// signed-in verified user; otherwise login (returning device) or onboarding.
class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _waitForAuthInit(AuthProvider auth) {
    if (auth.isInitialized) return Future.value();
    final completer = Completer<void>();
    void listener() {
      if (auth.isInitialized && !completer.isCompleted) completer.complete();
    }

    auth.addListener(listener);
    return completer.future
        .timeout(const Duration(seconds: 8), onTimeout: () {})
        .whenComplete(() => auth.removeListener(listener));
  }

  Future<void> _resolve() async {
    final auth = context.read<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;

    Widget destination;
    if (firebaseUser != null) {
      await _waitForAuthInit(auth);
      final user = auth.user;
      if (user != null && (user.isStaff || firebaseUser.emailVerified)) {
        destination = homeForUser(user);
      } else {
        destination = const LoginScreen();
      }
    } else {
      final hasLoggedInBefore = await const OnboardingPrefsService()
          .hasLoggedInBefore();
      destination = hasLoggedInBefore
          ? const LoginScreen()
          : const OnboardingScreen();
    }

    if (mounted) setState(() => _destination = destination);
  }

  @override
  Widget build(BuildContext context) {
    return _destination ?? const _SplashScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBrandLogos(),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
