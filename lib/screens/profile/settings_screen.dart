import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _isSavingPreference = false;

  // Handles resetting password via Firebase Auth email trigger
  Future<void> _handlePasswordReset() async {
    final email = context.read<AuthProvider>().user?.email;
    if (email == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _isSavingPreference = true);
    try {
      await context.read<AuthProvider>().updatePrivacySettings(
        allowNotifs: enabled,
      );
      await context.read<NotificationProvider>().loadNotifications();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save notification setting: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPreference = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDark,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PREFERENCES SECTION ───────────────────────
                  const _SettingHeader(title: 'Preferences'),
                  const SizedBox(height: 8),
                  _buildSettingsContainer([
                    _buildSwitchTile(
                      icon: Icons.notifications_none_rounded,
                      iconColor: AppColors.primary,
                      title: 'In-app notifications',
                      subtitle: 'Show account updates and unread badges',
                      value:
                          context
                              .watch<AuthProvider>()
                              .user
                              ?.allowNotifications ??
                          true,
                      onChanged: _isSavingPreference
                          ? null
                          : _setNotificationsEnabled,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── SECURITY SECTION ──────────────────────────
                  const _SettingHeader(title: 'Security'),
                  const SizedBox(height: 8),
                  _buildSettingsContainer([
                    _buildActionTile(
                      icon: Icons.lock_reset_rounded,
                      iconColor: Colors.orange,
                      title: 'Change Password',
                      subtitle: 'Send a secure reset link to your email',
                      onTap: _handlePasswordReset,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── INFRASTRUCTURE & LEGAL ────────────────────
                  const _SettingHeader(title: 'Information & Support'),
                  const SizedBox(height: 8),
                  _buildSettingsContainer([
                    _buildActionTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.textGrey,
                      title: 'App Version',
                      subtitle: 'v1.0.0',
                      trailing: const SizedBox.shrink(),
                      onTap: null,
                    ),
                  ]),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // Wraps tile items inside clean card constraints matching application aesthetics
  Widget _buildSettingsContainer(
    List<Widget> children, {
    Color? borderHighlight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderHighlight ?? Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 50,
    );
  }

  // Generates interactive action rows
  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color titleColor = AppColors.textDark,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textGrey,
          height: 1.3,
        ),
      ),
      trailing:
          trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textGrey,
            size: 18,
          ),
    );
  }

  // Generates system setting configuration toggle switch options
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setting Section Header Indicator ─────────────────────────────
class _SettingHeader extends StatelessWidget {
  const _SettingHeader({required this.title}) : isDanger = false;
  final String title;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDanger ? Colors.red.shade700 : AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
