import 'package:flutter/material.dart';

import '../core/constants/app_tokens.dart';

class RoundedTabBar extends StatelessWidget {
  const RoundedTabBar({super.key, required this.tabs, this.controller});

  final List<Widget> tabs;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: colors.primary.withValues(alpha: 0.04),
        borderRadius: AppRadius.pillAll,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: TabBar(
            controller: controller,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(2),
            indicator: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.pillAll,
            ),
            splashBorderRadius: AppRadius.pillAll,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurfaceVariant,
            tabs: tabs,
          ),
        ),
      ),
    );
  }
}
