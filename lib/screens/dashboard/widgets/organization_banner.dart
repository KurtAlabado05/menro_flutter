import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';

class OrganizationActiveBanner extends StatelessWidget {
  const OrganizationActiveBanner({super.key, required this.organizationName});

  final String organizationName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Organization access active. $organizationName',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.statusApproved.fade(0.08),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              color: AppColors.statusApproved,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organization access active',
                    style: TextStyle(
                      color: AppColors.statusApproved,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    organizationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrganizationPendingCard extends StatelessWidget {
  const OrganizationPendingCard({
    super.key,
    required this.onCheckStatus,
    required this.isChecking,
  });

  final VoidCallback onCheckStatus;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.statusPending.fade(0.08),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top, color: AppColors.statusPending),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Organization pending review',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Reporting, permits and projects unlock once your organization is verified. '
            'You can still read the local ordinances below.',
            style: TextStyle(color: AppColors.textDark, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: isChecking ? null : onCheckStatus,
              icon: isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Check status'),
            ),
          ),
        ],
      ),
    );
  }
}
