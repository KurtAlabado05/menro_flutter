import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../models/user_model.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../widgets/section_widgets.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = context.select<ReportProvider, int>(
      (p) => p.myReports.length,
    );
    final pending = context.select<ReportProvider, int>(
      (p) => p.myReports.where((r) => r.status == 'pending').length,
    );
    final resolved = context.select<ReportProvider, int>(
      (p) => p.myReports.where((r) => r.status == 'completed').length,
    );
    final projects = context.select<ProjectProvider, int>(
      (p) => p.myProjects.length,
    );

    return Row(
      children: [
        _StatTile(
          icon: Icons.assignment_outlined,
          label: 'Reports',
          value: reports,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatTile(
          icon: Icons.nature_outlined,
          label: 'Projects',
          value: projects,
          color: AppColors.accentTeal,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatTile(
          icon: Icons.hourglass_empty_rounded,
          label: 'Pending',
          value: pending,
          color: AppColors.statusPending,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatTile(
          icon: Icons.check_circle_outline,
          label: 'Resolved',
          value: resolved,
          color: AppColors.statusApproved,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: color.fade(0.07),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: color.fade(0.18)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({super.key, required this.user});

  final UserModel user;

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    final joined = user.joinedAt;
    final phone = user.phoneNumber;
    final address = user.completeAddress;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.person_outline,
            label: 'Account Info',
          ),
          const SizedBox(height: AppSpacing.sm),
          DetailRow(label: 'Full name', value: user.name),
          DetailRow(label: 'Email', value: user.email),
          if (phone != null && phone.isNotEmpty)
            DetailRow(label: 'Phone', value: phone),
          if (address != null && address.isNotEmpty)
            DetailRow(label: 'Address', value: address),
          DetailRow(
            label: 'Member since',
            value:
                '${_months[joined.month - 1]} ${joined.day}, ${joined.year}',
          ),
          DetailRow(
            label: 'Account type',
            value: user.accountType?.label ?? user.role.toUpperCase(),
          ),
        ],
      ),
    );
  }
}
