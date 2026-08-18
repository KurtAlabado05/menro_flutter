import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/cloudinary_image_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_provider.dart';
import 'settings_screen.dart';
import 'package:cenro_application/screens/profile/settings_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/status_config.dart'; // Import StatusConfig
import '../../widgets/empty_state.dart';
import '../../screens/project/project_details_screen.dart';
import '../../screens/report/report_details_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/tree_cutting_application_screen.dart';
import '../../screens/tree_cutting_permit_details_screen.dart';
import '../../models/report_model.dart';
import '../../models/project_model.dart';
import 'edit_profile_screen.dart'; // Adjust path directory to match your folder hierarchy

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _initialLoadDone = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingDoc = false;

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadDone) _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.reloadUser();
    if (!mounted) return;
    final userId = auth.user?.id;
    if (userId == null) return;
    await Future.wait([
      context.read<ReportProvider>().loadMyReports(userId),
      context.read<ProjectProvider>().loadProjects(),
    ]);

    if (mounted) setState(() => _initialLoadDone = true);
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textGrey,
                  size: 18,
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textGrey,
                  size: 18,
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await picked.readAsBytes();

      const cloudinary = CloudinaryImageService(
        cloudName: 'dfo5l4d4t',
        uploadPreset: 'flutter_upload_preset',
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatars/${uid}/profile_${ts}.jpg';

      final url = await cloudinary.uploadImage(
        bytes: bytes,
        fileName: fileName,
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarUrl': url,
      });

      if (mounted) {
        await context.read<AuthProvider>().reloadUser();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickAndUploadVerificationDoc(bool isOrg) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isOrg ? 'Upload Business Permit' : 'Upload Valid ID',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingDoc = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await picked.readAsBytes();

      const cloudinary = CloudinaryImageService(
        cloudName: 'dfo5l4d4t',
        uploadPreset: 'flutter_upload_preset',
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final docType = isOrg ? 'business_permit' : 'national_id';
      final fileName = 'verifications/${uid}/${docType}_${ts}.jpg';

      final url = await cloudinary.uploadImage(
        bytes: bytes,
        fileName: fileName,
      );

      final updateField = isOrg ? 'businessPermitUrl' : 'citizenNationalIdUrl';
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        updateField: url,
      });

      if (mounted) {
        await context.read<AuthProvider>().reloadUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully. Awaiting review.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingDoc = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final auth = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
                Icons.logout_rounded,
                color: Colors.red,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(fontSize: 14, color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await auth.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final initials = user.name.trim().isNotEmpty
              ? user.name.trim().split(' ').map((e) => e[0]).take(2).join()
              : 'U';

          final String? avatarUrl = user.avatarUrl;
          final bool isOrg = user.role == 'organization';
          final bool isVerified = user.isVerified ?? false;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Profile Header ──────────────────────
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                  color: AppColors.textGrey,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EditProfileScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.primary,
                                        size: 14,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Edit Profile',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _confirmSignOut,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        color: Colors.red,
                                        size: 14,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Sign Out',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _pickAndUploadPhoto,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.1),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(
                                        0.25,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: _isUploadingPhoto
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : avatarUrl != null &&
                                            avatarUrl.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            width: 96,
                                            height: 96,
                                            errorBuilder: (_, __, ___) =>
                                                Center(
                                                  child: Text(
                                                    initials.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 30,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            initials.toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                ),
                                if (!_isUploadingPhoto)
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                color: AppColors.textGrey,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOrg
                                          ? Icons.business_outlined
                                          : Icons.people_outline,
                                      color: AppColors.primary,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isOrg
                                          ? 'Organization'
                                          : 'Community Member',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final hasUploadedDoc = isOrg
                                      ? user.businessPermitUrl != null
                                      : user.citizenNationalIdUrl != null;

                                  Color badgeColor;
                                  IconData badgeIcon;
                                  String badgeText;

                                  if (isVerified) {
                                    badgeColor = Colors.green;
                                    badgeIcon = Icons.verified_user_outlined;
                                    badgeText = 'Verified';
                                  } else if (hasUploadedDoc) {
                                    badgeColor = Colors.orange;
                                    badgeIcon = Icons.hourglass_empty_rounded;
                                    badgeText = 'Pending Review';
                                  } else {
                                    badgeColor = Colors.red;
                                    badgeIcon = Icons.error_outline_rounded;
                                    badgeText = isOrg
                                        ? 'Upload Permit'
                                        : 'Upload ID';
                                  }

                                  return GestureDetector(
                                    onTap:
                                        (!isVerified && !hasUploadedDoc) &&
                                            !_isUploadingDoc
                                        ? () => _pickAndUploadVerificationDoc(
                                            isOrg,
                                          )
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: badgeColor.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _isUploadingDoc &&
                                                  !isVerified &&
                                                  !hasUploadedDoc
                                              ? SizedBox(
                                                  width: 13,
                                                  height: 13,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: badgeColor,
                                                      ),
                                                )
                                              : Icon(
                                                  badgeIcon,
                                                  color: badgeColor,
                                                  size: 13,
                                                ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isUploadingDoc &&
                                                    !isVerified &&
                                                    !hasUploadedDoc
                                                ? 'Uploading...'
                                                : badgeText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: badgeColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(color: Colors.grey.shade200, thickness: 1),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Stats Panel ───────────────────────────────
                SliverToBoxAdapter(
                  child: Consumer2<ReportProvider, ProjectProvider>(
                    builder: (context, rp, pp, _) {
                      final reports = rp.myReports;
                      final projects = pp.myProjects;
                      final pending = reports
                          .where((r) => r.status == 'pending')
                          .length;
                      final resolved = reports
                          .where((r) => r.status == 'completed')
                          .length;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel(
                              icon: Icons.bar_chart_rounded,
                              label: 'My Activity',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(
                                  icon: Icons.assignment_outlined,
                                  label: 'Reports',
                                  value: '${reports.length}',
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                _StatCard(
                                  icon: Icons.nature_outlined,
                                  label: 'Projects',
                                  value: '${projects.length}',
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 8),
                                _StatCard(
                                  icon: Icons.hourglass_empty_rounded,
                                  label: 'Pending',
                                  value: '$pending',
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                _StatCard(
                                  icon: Icons.check_circle_outline,
                                  label: 'Resolved',
                                  value: '$resolved',
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ── Account Information ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel(
                          icon: Icons.person_outline,
                          label: 'Account Info',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.badge_outlined,
                                label: 'Full Name',
                                value: user.name,
                                isFirst: true,
                              ),
                              _RowDivider(),
                              _InfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: user.email,
                              ),
                              if (user.phoneNumber != null &&
                                  user.phoneNumber!.isNotEmpty) ...[
                                _RowDivider(),
                                _InfoRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone Number',
                                  value: user.phoneNumber!,
                                ),
                              ],
                              if (user.completeAddress != null &&
                                  user.completeAddress!.isNotEmpty) ...[
                                _RowDivider(),
                                _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Address',
                                  value: user.completeAddress!,
                                ),
                              ],
                              _RowDivider(),
                              _InfoRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Member Since',
                                value:
                                    '${_getMonthName(user.joinedAt.month)} ${user.joinedAt.day}, ${user.joinedAt.year}',
                              ),
                              _RowDivider(),
                              _InfoRow(
                                icon: Icons.shield_outlined,
                                label: 'Role',
                                value: isOrg
                                    ? 'Organization'
                                    : 'Community Member',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── My Reports List ───────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                    child: _SectionLabel(
                      icon: Icons.flag_outlined,
                      label: 'My Reports',
                    ),
                  ),
                ),
                Consumer<ReportProvider>(
                  builder: (context, rp, _) {
                    if (rp.isLoading && rp.myReports.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }
                    if (rp.myReports.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No reports yet',
                          subtitle: 'Your submitted reports will appear here.',
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final r = rp.myReports[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _ReportTile(
                            title: r.title,
                            category: r.category,
                            location: r.location,
                            status: r.status,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReportDetailsScreen(reportId: r.id),
                              ),
                            ),
                          ),
                        );
                      }, childCount: rp.myReports.length),
                    );
                  },
                ),

                // ── My Projects List ──────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _SectionLabel(
                      icon: Icons.eco_outlined,
                      label: 'My Projects',
                    ),
                  ),
                ),
                Consumer2<ProjectProvider, AuthProvider>(
                  builder: (context, pp, authProvider, _) {
                    if (pp.isLoading && pp.myProjects.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }
                    if (pp.myProjects.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.nature_outlined,
                          title: 'No projects yet',
                          subtitle: 'Projects you join will appear here.',
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final p = pp.myProjects[index];
                        final userId = authProvider.user?.id ?? '';
                        final isJoined = p.participants.contains(userId);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _ProjectTile(
                            title: p.title,
                            category: p.category,
                            location: p.location,
                            status: p.status,
                            isJoined: isJoined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProjectDetailsScreen(projectId: p.id),
                              ),
                            ),
                            onToggle: () async {
                              if (isJoined) {
                                await pp.leaveProject(p.id, userId);
                              } else {
                                await pp.joinProject(p.id, userId);
                              }
                            },
                          ),
                        );
                      }, childCount: pp.myProjects.length),
                    );
                  },
                ),

                // ── Tree Cutting Permits ─────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: _SectionLabel(
                            icon: Icons.eco_outlined,
                            label: 'Tree Cutting Permits',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Apply for a Tree Cutting Permit',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TreeCuttingApplicationScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final userId = auth.user?.id;
                    if (userId == null || userId.trim().isEmpty) {
                      return const SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.lock_outline,
                          title: 'Sign in required',
                          subtitle: 'Please sign in to view your permits.',
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('tree_cutting_permits')
                          .where('submittedByUid', isEqualTo: userId)
                          .orderBy('submittedAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Failed to load tree cutting permits.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: EmptyState(
                              icon: Icons.eco_outlined,
                              title: 'No permits yet',
                              subtitle:
                                  'Your tree cutting permit applications will appear here.',
                            ),
                          );
                        }

                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final data = docs[index].data();
                            final species =
                                (data['kindOfTree'] as String?)?.trim() ?? '';
                            final numberOfTrees = data['numberOfTrees'];
                            final status =
                                (data['status'] as String?)?.trim() ?? '';

                            final int trees = numberOfTrees is int
                                ? numberOfTrees
                                : int.tryParse('$numberOfTrees') ?? 0;

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _PermitTile(
                                title: species.isEmpty
                                    ? 'Tree Cutting Application'
                                    : species,
                                subtitle: trees > 0
                                    ? 'Trees: $trees'
                                    : (status.isNotEmpty ? status : 'Pending'),
                                status: status,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TreeCuttingPermitDetailsScreen(
                                            permitId: docs[index].id,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }, childCount: docs.length),
                        );
                      },
                    );
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Section Label Widget ──────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

// ── Stat Card Widget ──────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row Widget ───────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, isFirst ? 14 : 10, 14, isLast ? 14 : 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
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

// ── Row Divider Widget ────────────────────────────────────────────
class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 14,
    );
  }
}

// ── Report Tile Widget ────────────────────────────────────────────
class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.category,
    required this.location,
    required this.status,
    required this.onTap,
  });
  final String title;
  final String category;
  final String location;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flag_outlined,
                size: 20,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 11,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusConfig.buildBadge(status), // Updated using StatusConfig
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textGrey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permit Tile Widget ────────────────────────────────────────────
class _PermitTile extends StatelessWidget {
  const _PermitTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusConfig.buildBadge(
                  status.isEmpty ? 'pending' : status,
                ), // Updated using StatusConfig
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textGrey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Project Tile ─────────────────────────────────────────────────
class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.title,
    required this.category,
    required this.location,
    required this.status,
    required this.isJoined,
    required this.onTap,
    required this.onToggle,
  });
  final String title;
  final String category;
  final String location;
  final String status;
  final bool isJoined;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 11,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusConfig.buildBadge(status), // Updated using StatusConfig
                const SizedBox(height: 6),
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isJoined
                          ? Colors.grey.withOpacity(0.08)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isJoined
                            ? Colors.grey.withOpacity(0.2)
                            : AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isJoined ? 'Leave' : 'Join',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isJoined ? Colors.grey : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
