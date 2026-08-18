import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModePlaceholder = false;
  bool _isLoading = false;

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

  // Visual dialog for account deletion confirmation (App Store compliant requirement)
  Future<void> _confirmAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your reported issues, files, and permit history will be permanently deleted.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textGrey,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account re-authentication required to delete account permanently.',
          ),
        ),
      );
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
                      title: 'Push Notifications',
                      subtitle: 'Receive updates regarding status reports',
                      value: _notificationsEnabled,
                      onChanged: (val) =>
                          setState(() => _notificationsEnabled = val),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: Colors.indigo,
                      title: 'Dark Mode',
                      subtitle: 'Toggle dark interface preference',
                      value: _darkModePlaceholder,
                      onChanged: (val) {
                        setState(() => _darkModePlaceholder = val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme settings coming soon!'),
                          ),
                        );
                      },
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
                      icon: Icons.description_outlined,
                      iconColor: Colors.teal,
                      title: 'Terms of Service',
                      subtitle: 'Review user rules and regulations',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildActionTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: Colors.blue,
                      title: 'Privacy Policy',
                      subtitle: 'Data usage governance practices',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildActionTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.textGrey,
                      title: 'App Version',
                      subtitle: 'v1.0.0 (Production Setup Build)',
                      trailing: const SizedBox.shrink(),
                      onTap: null,
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // ── DANGER ZONE ───────────────────────────────
                  const _SettingHeader(title: 'Danger Zone', isDanger: true),
                  const SizedBox(height: 8),
                  _buildSettingsContainer([
                    _buildActionTile(
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.red,
                      title: 'Delete My Account',
                      subtitle: 'Permanently remove all your user footprints',
                      titleColor: Colors.red,
                      onTap: _confirmAccountDeletion,
                    ),
                  ], borderHighlight: Colors.red.withOpacity(0.15)),

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
            color: Colors.black.withOpacity(0.01),
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
          color: iconColor.withOpacity(0.08),
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
    required ValueChanged<bool> onChanged,
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
              color: iconColor.withOpacity(0.08),
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
  const _SettingHeader({required this.title, this.isDanger = false});
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
