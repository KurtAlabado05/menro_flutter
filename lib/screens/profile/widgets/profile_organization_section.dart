import 'package:flutter/material.dart';

import '../../../core/constants/app_tokens.dart';
import '../../../models/user_model.dart';
import '../join_organization_screen.dart';
import '../organization_application_screen.dart';
import '../organization_review_screen.dart';
import 'profile_flags.dart';

class OrganizationStatusBanner extends StatelessWidget {
  const OrganizationStatusBanner({super.key, required this.flags});

  final ProfileFlags flags;

  @override
  Widget build(BuildContext context) {
    final color = flags.orgBannerColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.fade(0.08),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.fade(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(flags.orgBannerIcon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              flags.orgBannerMessage,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrganizationActions extends StatelessWidget {
  const OrganizationActions({
    super.key,
    required this.user,
    required this.flags,
  });

  final UserModel user;
  final ProfileFlags flags;

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';
    if (!flags.canApplyForOrganization &&
        !flags.canRequestRepresentation &&
        !isAdmin) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        if (flags.canApplyForOrganization)
          FilledButton.icon(
            onPressed: () =>
                _open(context, const OrganizationApplicationScreen()),
            icon: const Icon(Icons.business_outlined, size: 18),
            label: const Text('Apply as organization'),
          ),
        if (flags.canRequestRepresentation)
          OutlinedButton.icon(
            onPressed: () => _open(context, const JoinOrganizationScreen()),
            icon: const Icon(Icons.business_center_outlined, size: 18),
            label: const Text('Request to represent'),
          ),
        if (isAdmin)
          OutlinedButton.icon(
            onPressed: () => _open(context, const OrganizationReviewScreen()),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Review organization requests'),
          ),
      ],
    );
  }
}
