import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';
import 'status_badge.dart';

/// A generic tappable row for a submission-like record (report, permit,
/// project, ...): leading icon, title/subtitle, and a trailing status badge.
/// Shared across the profile activity lists and the submission hub screens.
class ActivityListTile extends StatelessWidget {
  const ActivityListTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.status,
    required this.onTap,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? status;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: AppColors.primaryDark.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.fade(0.1),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: status, fontSize: 10),
                  ?action,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
