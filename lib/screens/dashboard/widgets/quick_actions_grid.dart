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

class _QuickActionTile extends StatefulWidget {
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
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = widget.badgeCount > 0
        ? '${widget.title}, ${widget.badgeCount} ${widget.badgeNoun}${widget.badgeCount == 1 ? '' : 's'}'
        : widget.title;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Material(
          color: AppColors.cardWhite,
          borderRadius: AppRadius.lgAll,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (highlighted) {
              if (_isPressed != highlighted) {
                setState(() => _isPressed = highlighted);
              }
            },
            borderRadius: AppRadius.lgAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg,
                horizontal: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Badge(
                    isLabelVisible: widget.badgeCount > 0,
                    label: Text(widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}'),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 26),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.title,
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
      ),
    );
  }
}
