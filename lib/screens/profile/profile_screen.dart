import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/cloudinary_image_service.dart';
import '../../services/organization_registration_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/skeleton_loader.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'widgets/profile_activity_lists.dart';
import 'widgets/profile_flags.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_organization_section.dart';
import 'widgets/profile_overview.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const CloudinaryImageService _cloudinary = CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  bool _isUploadingPhoto = false;
  bool _isUploadingDoc = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final reports = context.read<ReportProvider>();
    final projects = context.read<ProjectProvider>();
    await auth.reloadUser();
    final userId = auth.user?.id;
    if (userId == null) return;
    await Future.wait([reports.loadMyReports(userId), projects.loadProjects()]);
  }

  Future<void> _changePhoto() async {
    final source = await showImageSourceSheet(
      context,
      title: 'Change Profile Photo',
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (picked == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.user?.id;
    if (uid == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _cloudinary.uploadImage(
        bytes: bytes,
        fileName:
            'avatars/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'avatarUrl': url,
      });
      await auth.reloadUser();
      if (mounted) {
        showAppSnackBar(
          context,
          'Profile photo updated.',
          type: AppMessageType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not update your photo. Check your connection and try again.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _uploadVerificationDoc({required bool isOrg}) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (isOrg &&
        (user.organizationId == null || user.organizationStatus != 'pending')) {
      showAppSnackBar(
        context,
        'Only pending organization applications can update a permit.',
        type: AppMessageType.warning,
      );
      return;
    }

    final Uint8List bytes;
    final String originalName;
    if (isOrg) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;
      bytes = file.bytes!;
      originalName = file.name;
    } else {
      final source = await showImageSourceSheet(
        context,
        title: 'Upload Valid ID',
      );
      if (source == null || !mounted) return;
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null || !mounted) return;
      bytes = await picked.readAsBytes();
      originalName = picked.name;
    }

    if (!mounted) return;
    setState(() => _isUploadingDoc = true);
    try {
      final uid = user.id;
      final docType = isOrg ? 'business_permit' : 'national_id';
      final fileName =
          'verifications/$uid/${docType}_${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final url = originalName.toLowerCase().endsWith('.pdf')
          ? await _cloudinary.uploadRawFile(bytes: bytes, fileName: fileName)
          : await _cloudinary.uploadImage(bytes: bytes, fileName: fileName);

      if (isOrg) {
        await OrganizationRegistrationService().updateOrganizationPermit(
          organizationId: user.organizationId!,
          permitDocumentUrl: url,
        );
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'citizenNationalIdUrl': url,
        });
      }

      await auth.reloadUser();
      if (mounted) {
        showAppSnackBar(
          context,
          isOrg
              ? 'Business permit updated and submitted for review.'
              : 'Document uploaded. Awaiting review.',
          type: AppMessageType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not upload the document. Check your connection and try again.',
          type: AppMessageType.error,
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
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.statusRejected),
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, UserModel?>((a) => a.user);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: user == null
            ? const SkeletonList(count: 3)
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _buildContent(user),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(UserModel user) {
    final flags = ProfileFlags.from(user);
    const gap = SizedBox(height: AppSpacing.xl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _open(const EditProfileScreen()),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _open(const SettingsScreen()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ProfileHeader(
          user: user,
          flags: flags,
          isUploadingPhoto: _isUploadingPhoto,
          isUploadingDoc: _isUploadingDoc,
          onChangePhoto: _changePhoto,
          onUploadCitizenId: () => _uploadVerificationDoc(isOrg: false),
          onUploadOrgPermit: () => _uploadVerificationDoc(isOrg: true),
        ),
        if (flags.showOrgBanner) ...[
          const SizedBox(height: AppSpacing.lg),
          OrganizationStatusBanner(flags: flags),
        ],
        const SizedBox(height: AppSpacing.lg),
        OrganizationActions(user: user, flags: flags),
        gap,
        const ProfileStats(),
        gap,
        ProfileAccountCard(user: user),
        gap,
        const ProfileReportsSection(),
        gap,
        const ProfileProjectsSection(),
        gap,
        ProfilePermitsSection(userId: user.id),
        gap,
        OutlinedButton.icon(
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.statusRejected,
            side: BorderSide(color: AppColors.statusRejected.fade(0.4)),
          ),
        ),
      ],
    );
  }
}
