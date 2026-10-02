import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_tokens.dart';
import '../../models/account_type.dart';
import '../../providers/auth_provider.dart';
import 'widgets/application_readiness_card.dart';
import 'widgets/ordinance_banner.dart';
import 'widgets/organization_banner.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/status_updates_card.dart';

class DashboardScreen extends StatefulWidget {
  final ScrollController scrollController;
  const DashboardScreen({super.key, required this.scrollController});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pendingReports = 0;
  int _pendingPermits = 0;
  bool _isCheckingOrg = false;
  String? _metricsUserId;

  Future<void> _loadPendingCounts(String userId) async {
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db
            .collection('reports')
            .where('submittedBy', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        db
            .collection('tree_cutting_permits')
            .where('submittedByUid', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingReports = results[0].count ?? 0;
        _pendingPermits = results[1].count ?? 0;
      });
    } catch (e) {
      debugPrint('Dashboard pending counts failed: $e');
    }
  }

  Future<void> _refresh(AuthProvider auth) async {
    await auth.reloadUser();
    final id = auth.user?.id;
    if (id != null) await _loadPendingCounts(id);
  }

  Future<void> _checkOrganizationStatus(AuthProvider auth) async {
    setState(() => _isCheckingOrg = true);
    try {
      await auth.reloadUser();
    } finally {
      if (mounted) setState(() => _isCheckingOrg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user != null && _metricsUserId != user.id) {
      _metricsUserId = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPendingCounts(user.id);
      });
    }

    final isOrg = user?.accountType == AccountType.organization;
    final hasOrgAccess = user?.hasApprovedOrganizationAccess ?? false;
    final orgPending = isOrg && !hasOrgAccess;
    final orgName = (user?.activeOrganizationName?.trim().isNotEmpty ?? false)
        ? user!.activeOrganizationName!.trim()
        : user?.name ?? '';

    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => _refresh(auth),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (orgPending) ...[
                  OrganizationPendingCard(
                    isChecking: _isCheckingOrg,
                    onCheckStatus: () => _checkOrganizationStatus(auth),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Local Ordinances', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  const OrdinanceBanner(),
                ] else ...[
                  if (hasOrgAccess) ...[
                    OrganizationActiveBanner(organizationName: orgName),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (user != null) ...[
                    StatusUpdatesCard(userId: user.id),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  Text('Quick Actions', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  QuickActionsGrid(
                    pendingReports: _pendingReports,
                    pendingPermits: _pendingPermits,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Local Ordinances', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  const OrdinanceBanner(),
                  const SizedBox(height: AppSpacing.xl),
                  const ApplicationReadinessCard(),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
