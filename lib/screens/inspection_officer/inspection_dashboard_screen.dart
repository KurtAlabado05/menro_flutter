import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import 'case_documentation_list_screen.dart';
import 'case_visit_planner_screen.dart';
import 'inspection_queue_screen.dart';
import 'tree_identification_screen.dart';

/// Landing screen for the Inspection Officer role.
/// Case Documentation and Tree Identification are added in later phases.
class InspectionDashboardScreen extends StatelessWidget {
  const InspectionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final queueCount = context.watch<InspectionProvider>().queue.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Welcome, ${user?.name ?? 'Inspection Officer'}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inspection Officer Module',
            style: TextStyle(color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          _ModuleCard(
            icon: Icons.assignment_outlined,
            title: 'Inspection Queue',
            subtitle:
                'Review environmental reports and tree-cutting applications.',
            trailing: Chip(
              label: Text('$queueCount'),
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
              labelStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Inspection Queue'),
                    backgroundColor: AppColors.primary,
                  ),
                  body: const InspectionQueueScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.fact_check_outlined,
            title: 'Case Documentation',
            subtitle:
                'Record onsite environmental and tree cutting inspections.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CaseDocumentationListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.route_outlined,
            title: 'Visit Planner',
            subtitle: 'Review scheduled field visits and their map sequence.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CaseVisitPlannerScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.park_outlined,
            title: 'Tree Identification',
            subtitle: 'Identify tree species using camera or uploaded photos.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TreeIdentificationScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
