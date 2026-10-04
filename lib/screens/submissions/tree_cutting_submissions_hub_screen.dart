import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/constants/status_config.dart';
import '../../widgets/activity_list_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/rounded_tab_bar.dart';
import '../tree_cutting_application_screen.dart';
import '../tree_cutting_permit_details_screen.dart';

class TreeCuttingSubmissionsHubScreen extends StatefulWidget {
  const TreeCuttingSubmissionsHubScreen({super.key});

  @override
  State<TreeCuttingSubmissionsHubScreen> createState() =>
      _TreeCuttingSubmissionsHubScreenState();
}

class _TreeCuttingSubmissionsHubScreenState
    extends State<TreeCuttingSubmissionsHubScreen> {
  final _db = FirebaseFirestore.instance;

  /// Tolerates malformed Firestore data (e.g. a status stored as a map).
  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      if (value['status'] is String) return (value['status'] as String).trim();
      if (value['value'] is String) return (value['value'] as String).trim();
      return '';
    }
    return value.toString();
  }

  Widget _buildPermitsTab({
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
          final status = _safeString(doc.data()['status']);
          final isResolved = StatusConfig.isCompletedStatus(status);
          return resolved ? isResolved : !isResolved;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.note_alt_outlined,
            title: resolved
                ? 'No resolved permit applications.'
                : 'No active permit applications. Tap below to start a new request.',
            subtitle:
                'MENRO workflow updates will show up here as they are processed.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            96,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            final applicationId = _safeString(data['applicationNumber']);
            final permitNo = applicationId.isEmpty
                ? 'Permit Application #${doc.id.substring(0, 4)}'
                : 'Permit Application #$applicationId';

            final status = _safeString(data['status']);
            final justification = _safeString(data['reasonForRequest']);

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
            'Please sign in to view your permit applications.',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'tree_cutting_submissions_hub_fab',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TreeCuttingApplicationScreen(),
              ),
            );
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Apply for Permit'),
        ),
        body: Column(
          children: [
            const RoundedTabBar(
              tabs: [Tab(text: 'Active'), Tab(text: 'Resolved')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPermitsTab(
                    resolved: false,
                    currentUserId: currentUserId,
                  ),
                  _buildPermitsTab(
                    resolved: true,
                    currentUserId: currentUserId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
