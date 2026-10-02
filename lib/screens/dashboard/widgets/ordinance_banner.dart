import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../ordinances_screen.dart';

class OrdinanceBanner extends StatelessWidget {
  const OrdinanceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Local ordinances. Tap to view all local ordinances.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: AppRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrdinancesScreen()),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/ordinances/follow_environmental_rules.png',
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: AppColors.primary.fade(0.08),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.policy_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.lg,
                  ),
                  color: AppColors.primary.fade(0.06),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.policy_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'View all local ordinances',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
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
