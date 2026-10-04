import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart' as app_auth_provider;
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_brand_logos.dart';
import '../../services/onboarding_prefs_service.dart';
import 'register_screen.dart';
import 'role_home.dart';
import '../onboarding/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingReset = false;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Load the Firestore profile first so the email-verification gate
      // below can be skipped for staff accounts (admin-created accounts
      // are trusted immediately, matching the web admin's login behavior).
      if (!mounted) return;
      final authProvider = context.read<app_auth_provider.AuthProvider>();
      await authProvider.reloadUser();
      final loadedUser = authProvider.user;
      final isStaff = loadedUser?.isStaff ?? false;

      if (!isStaff &&
          userCredential.user != null &&
          !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        await authProvider.logout();
        if (mounted) {
          showAppSnackBar(
            context,
            'Email not verified. A new link has been sent to your inbox.',
            type: AppMessageType.warning,
          );
        }
        return;
      }

      await const OnboardingPrefsService().markLoggedIn();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => homeForUser(loadedUser)),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Login failed: ${e.code} - ${e.message}');
      final String errorMessage = switch (e.code) {
        'user-not-found' => "No account found for this email.",
        'wrong-password' ||
        'invalid-credential' => "Incorrect email or password.",
        'user-disabled' => "This account has been disabled.",
        'invalid-email' => "The email address is badly formatted.",
        'too-many-requests' =>
          "Too many failed attempts. Please try again later.",
        'operation-not-allowed' =>
          "Email/password login is not enabled in Firebase.",
        'network-request-failed' =>
          "Network error. Check your internet connection and try again.",
        _ => "Login failed (${e.code}). Please try again.",
      };
      if (mounted) {
        showAppSnackBar(context, errorMessage, type: AppMessageType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Something went wrong. Please try again.',
          type: AppMessageType.error,
        );
      }
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      showAppSnackBar(
        context,
        'Enter a valid email above first, then tap Forgot Password.',
        type: AppMessageType.warning,
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        showAppSnackBar(
          context,
          'If an account exists for that email, a reset link has been sent.',
          type: AppMessageType.success,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.code == 'network-request-failed'
              ? 'Network error. Check your internet connection and try again.'
              : 'Could not send the reset link. Please try again.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: AppBrandLogos(size: 112),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'EcoMap',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'In partnership with MENRO & DENR-CENRO Baliwag',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 40),
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        enabled: !_isLoading,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_isLoading,
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: (_isLoading || _isSendingReset)
                              ? null
                              : _handleForgotPassword,
                          child: _isSendingReset
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Forgot Password?'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Login',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                            child: const Text(
                              'Register',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OnboardingScreen(
                                    isReplay: true,
                                  ),
                                ),
                              ),
                        child: const Text('View app introduction'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
