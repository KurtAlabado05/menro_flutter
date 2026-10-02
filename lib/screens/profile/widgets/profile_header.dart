import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../models/user_model.dart';
import 'profile_flags.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.flags,
    required this.isUploadingPhoto,
    required this.isUploadingDoc,
    required this.onChangePhoto,
    required this.onUploadCitizenId,
    required this.onUploadOrgPermit,
  });

  final UserModel user;
  final ProfileFlags flags;
  final bool isUploadingPhoto;
  final bool isUploadingDoc;
  final VoidCallback onChangePhoto;
  final VoidCallback onUploadCitizenId;
  final VoidCallback onUploadOrgPermit;

  String get _initials {
    final parts = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    final value = parts.map((p) => p[0]).join().toUpperCase();
    return value.isEmpty ? 'U' : value;
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.accountType?.label ?? user.role.toUpperCase();

    return Column(
      children: [
        _Avatar(
          avatarUrl: user.avatarUrl,
          initials: _initials,
          uploading: isUploadingPhoto,
          onTap: onChangePhoto,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            _InfoChip(
              icon: flags.isOrg
                  ? Icons.business_outlined
                  : Icons.person_outline,
              label: roleLabel,
              color: AppColors.primary,
            ),
            _InfoChip(
              icon: flags.badge.icon,
              label: flags.badge.label,
              color: flags.badge.color,
            ),
          ],
        ),
        if (flags.canUploadCitizenId) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: isUploadingDoc ? null : onUploadCitizenId,
            icon: isUploadingDoc ? const _ButtonSpinner() : const Icon(Icons.badge_outlined),
            label: Text(isUploadingDoc ? 'Uploading...' : 'Upload valid ID to get verified'),
          ),
        ],
        if (flags.canManageOrgPermit) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: isUploadingDoc ? null : onUploadOrgPermit,
            icon: isUploadingDoc
                ? const _ButtonSpinner()
                : Icon(
                    flags.hasUploadedDoc
                        ? Icons.edit_document
                        : Icons.upload_file_outlined,
                  ),
            label: Text(
              isUploadingDoc
                  ? 'Uploading...'
                  : flags.hasUploadedDoc
                  ? 'Replace business permit'
                  : 'Upload business permit',
            ),
          ),
        ],
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarUrl,
    required this.initials,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String initials;
  final bool uploading;
  final VoidCallback onTap;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final initialsView = Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: InkResponse(
        onTap: uploading ? null : onTap,
        radius: _size / 2 + 8,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.fade(0.1),
                border: Border.all(color: AppColors.primary.fade(0.25), width: 2),
              ),
              child: uploading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : hasImage
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        width: _size,
                        height: _size,
                        errorBuilder: (_, _, _) => initialsView,
                      ),
                    )
                  : initialsView,
            ),
            if (!uploading)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.fade(0.08),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.fade(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
