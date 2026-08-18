import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../screens/tree_cutting_application_screen.dart';
import '../../screens/tree_cutting_permit_details_screen.dart';
import '../../widgets/empty_state.dart';

class TreeCuttingSubmissionsHubScreen extends StatefulWidget {
  const TreeCuttingSubmissionsHubScreen({super.key});

  @override
  State<TreeCuttingSubmissionsHubScreen> createState() =>
      _TreeCuttingSubmissionsHubScreenState();
}

class _TreeCuttingSubmissionsHubScreenState
    extends State<TreeCuttingSubmissionsHubScreen> {
  final _db = FirebaseFirestore.instance;

  // 🟢 FIXED: Robust utility to parse incoming dynamic data without risking strict type-casting crashes
  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      if (value.containsKey('status') && value['status'] is String) {
        return (value['status'] as String).trim();
      }
      if (value.containsKey('value') && value['value'] is String) {
        return (value['value'] as String).trim();
      }
      return '';
    }
    return value.toString();
  }

  ({String label, Color color}) _permitChip(String status) {
    final normalized = status.toLowerCase().trim().replaceAll('_', ' ');

    switch (normalized) {
      case 'draft':
        return (label: '⚪ Draft', color: Colors.grey);
      case 'under review':
      case 'inspection in progress':
        return (label: '🟠 Under Review', color: Colors.orange);
      case 'site inspection scheduled':
        return (label: '🟣 Site Inspection Scheduled', color: Colors.purple);
      case 'approved':
      case 'approved by denr':
      case 'denr approved':
        return (label: '🟢 Approved', color: Colors.green);
      case 'denied':
      case 'rejected':
        return (label: '🔴 Denied', color: Colors.red);
      default:
        if (normalized == 'resolved') {
          return (label: '🟢 Approved', color: Colors.green);
        }
        return (label: '🟠 Under Review', color: Colors.orange);
    }
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  bool _isResolvedPermitStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'approved_by_denr' ||
        normalized == 'approved' ||
        normalized == 'resolved' ||
        normalized == 'denr approved';
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load tree cutting permits: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          // 🟢 FIXED: Safe conversion function handles any structural schema anomalies safely
          final status = _safeString(doc.data()['status']);
          final isResolved = _isResolvedPermitStatus(status);
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
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            // 🟢 FIXED: Eliminated the crashing direct "as String?" typecasts
            final applicationId = _safeString(data['applicationNumber']);
            final permitNo = applicationId.isEmpty
                ? 'Permit Application #${doc.id.substring(0, 4)}'
                : 'Permit Application #$applicationId';

            final status = _safeString(data['status']);
            final chip = _permitChip(status);

            final justification = _safeString(data['reasonForRequest']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TreeCuttingPermitDetailsScreen(permitId: doc.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                permitNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildStatusChip(
                              label: chip.label,
                              color: chip.color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (justification.isNotEmpty) ...[
                          Text(
                            justification,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TreeCuttingPermitDetailsScreen(
                                        permitId: doc.id,
                                      ),
                                ),
                              );
                            },
                            child: const Text(
                              'View Details',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
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
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          title: const Text(
            'Tree Cutting Permits',
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
          // 🟢 FIXED: Explicit hero tag disconnects it from other FloatingActionButtons across subtrees
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
        body: TabBarView(
          children: [
            _buildPermitsTab(resolved: false, currentUserId: currentUserId),
            _buildPermitsTab(resolved: true, currentUserId: currentUserId),
          ],
        ),
      ),
    );
  }
}
