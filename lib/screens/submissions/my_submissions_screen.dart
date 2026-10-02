import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/constants/status_config.dart';
import '../../widgets/activity_list_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../report/report_details_screen.dart';
import '../tree_cutting_permit_details_screen.dart';
import 'report_input_screen.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  final _db = FirebaseFirestore.instance;

  DateTime? _safeTimestampToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isResolvedReportStatus(String status) =>
      status.toLowerCase().trim() == 'resolved';

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '—';
    return dt.toLocal().toString().split('.').first;
  }

  Widget _reportsTab({required bool resolved, required String currentUserId}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('reports')
          .where('submittedBy', isEqualTo: currentUserId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your reports',
            subtitle: 'Check your connection and try again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(count: 3);
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final status = (doc.data()['status'] as String?)?.trim() ?? '';
          final isResolved = _isResolvedReportStatus(status);
          return resolved ? isResolved : !isResolved;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.cleaning_services_outlined,
            title: resolved
                ? 'No resolved reports yet.'
                : "You haven't reported any issues yet.",
            subtitle: resolved
                ? 'Resolved reports will appear here once MENRO completes the action.'
                : 'Tap the button below to file your first report.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            96,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            final category = (data['category'] as String?)?.trim() ?? '';
            final status = (data['status'] as String?)?.trim() ?? '';
            final location = (data['location'] as String?)?.trim() ?? '';
            final submittedAt = _safeTimestampToDate(data['submittedAt']);

            final subtitle = location.isNotEmpty
                ? (submittedAt == null
                      ? location
                      : '$location • ${_formatShortDate(submittedAt)}')
                : 'Submitted • ${_formatShortDate(submittedAt)}';

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ActivityListTile(
                icon: Icons.flag_outlined,
                color: StatusConfig.getColor(status),
                title: category.isEmpty ? 'Uncategorized' : category,
                subtitle: subtitle,
                status: status,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportDetailsScreen(reportId: doc.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _treePermitsTab({
    required bool resolved,
    required String currentUserId,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('tree_cutting_permits')
          .where('submittedByUid', isEqualTo: currentUserId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your permits',
            subtitle: 'Check your connection and try again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(count: 3);
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final status = (doc.data()['status'] as String?)?.trim() ?? '';
          final isResolved = StatusConfig.isCompletedStatus(status);
          return resolved ? isResolved : !isResolved;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.note_alt_outlined,
            title: 'No ${resolved ? 'resolved' : 'active'} permit applications.',
            subtitle: 'Tap below to start a new request.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            96,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            final applicationId = (data['applicationNumber'] as String?)
                ?.trim();
            final permitNo = (applicationId == null || applicationId.isEmpty)
                ? 'Permit Application #${doc.id.substring(0, 4)}'
                : 'Permit Application #$applicationId';

            final status = (data['status'] as String?)?.trim() ?? '';
            final justification =
                (data['reasonForRequest'] as String?)?.trim() ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ActivityListTile(
                icon: Icons.park_outlined,
                color: StatusConfig.getColor(status),
                title: permitNo,
                subtitle: justification.isEmpty ? null : justification,
                status: status,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TreeCuttingPermitDetailsScreen(permitId: doc.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null || currentUserId.trim().isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Please sign in to view your submissions.',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          title: const Text(
            'My Reports',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Resolved'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportInputScreen()),
            );
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('New Report'),
        ),
        body: TabBarView(
          children: [
            _buildCompositeHub(currentUserId: currentUserId, resolved: false),
            _buildCompositeHub(currentUserId: currentUserId, resolved: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCompositeHub({
    required String currentUserId,
    required bool resolved,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              resolved ? 'Resolved Reports' : 'Active Reports',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(
                height: 420,
                child: _reportsTab(
                  resolved: resolved,
                  currentUserId: currentUserId,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: const Text(
                  'Tree Cutting Permits',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              SizedBox(
                height: 420,
                child: _treePermitsTab(
                  resolved: resolved,
                  currentUserId: currentUserId,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}
