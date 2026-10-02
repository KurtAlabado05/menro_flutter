import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../project/project_list_wrapper_screen.dart';
import '../../submissions/my_submissions_screen.dart';
import '../../submissions/report_input_screen.dart';
import '../../tree_cutting_application_screen.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    required this.pendingReports,
    required this.pendingPermits,
  });

  final int pendingReports;
  final int pendingPermits;

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _QuickActionTile(
        title: 'Report Issue',
        icon: Icons.campaign_outlined,
        color: Colors.orange.shade800,
        badgeCount: pendingReports,
        badgeNoun: 'pending report',
        onTap: () => _open(context, const ReportInputScreen()),
      ),
      _QuickActionTile(
        title: 'Apply Permit',
        icon: Icons.note_add_outlined,
        color: AppColors.primary,
        badgeCount: pendingPermits,
        badgeNoun: 'pending permit',
        onTap: () => _open(context, const TreeCuttingApplicationScreen()),
      ),
      _QuickActionTile(
        title: 'Join Projects',
        icon: Icons.nature_people_outlined,
        color: Colors.green.shade700,
        onTap: () => _open(context, const ProjectListWrapperScreen()),
      ),
      _QuickActionTile(
        title: 'My Submissions',
        icon: Icons.folder_open_outlined,
        color: Colors.blueGrey.shade700,
        onTap: () => _open(context, const MySubmissionsScreen()),
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeNoun = '',
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
  final String badgeNoun;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = badgeCount > 0
        ? '$title, $badgeCount $badgeNoun${badgeCount == 1 ? '' : 's'}'
        : title;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
