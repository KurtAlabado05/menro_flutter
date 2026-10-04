import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/gradient_utils.dart';
import 'animations.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData actionIcon;
  final bool useGradientIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.useGradientIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeInAnimation(
          duration: const Duration(milliseconds: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleInAnimation(
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: useGradientIcon
                      ? GradientUtils.primaryGradientDecoration(radius: 40)
                      : BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: useGradientIcon ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textGrey,
                    height: 1.5,
                  ),
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Container(
                    decoration:
                        GradientUtils.primaryGradientDecoration(radius: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(actionIcon, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              actionLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


