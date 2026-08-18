import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/status_config.dart';
import '../../screens/report/report_details_screen.dart';
import '../../screens/report/report_screen.dart';
import '../../screens/tree_cutting_application_screen.dart';
import '../../screens/tree_cutting_permit_details_screen.dart';
import '../../widgets/empty_state.dart';

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

  bool _isResolvedReportStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'resolved';
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '—';
    final s = dt.toLocal().toString().split('.').first;
    return s;
  }

  // Reports status mapping to your chip requirements
  ({String label, Color color}) _reportsChip(String status) {
    final normalized = status.toLowerCase().trim().replaceAll('_', ' ');

    if (_isResolvedReportStatus(status)) {
      return (label: '🟢 Resolved', color: Colors.green);
    }

    // Pending Review = pending/submitted variants
    if (normalized == 'submitted' || normalized == 'pending') {
      return (label: '🟠 Pending Review', color: Colors.orange);
    }

    // In Progress = inspection_in_progress, forwarded, approved, etc (non-resolved)
    return (label: '🔵 In Progress', color: Colors.blue);
  }

  // Tree cutting permit status mapping to your workflow requirements
  ({String label, Color color}) _permitChip(String status) {
    final normalized = status.toLowerCase().trim().replaceAll('_', ' ');

    switch (normalized) {
      case 'draft':
        return (label: '⚪ Draft', color: Colors.grey);
      case 'under review':
      case 'inspection in progress':
      case 'inspection in progress ': // tolerate
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
        // Fallback to existing backend statuses
        if (normalized == 'resolved') {
          return (label: '🟢 Approved', color: Colors.green);
        }
        // submitted/inspection/forwarded map to Under Review/In Progress group
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

  Widget _reportsTab({required bool resolved, required String currentUserId}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('reports')
          .where('submittedBy', isEqualTo: currentUserId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load report submissions: ${snapshot.error}',
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
          final status = (doc.data()['status'] as String?)?.trim() ?? '';
          final isResolved = _isResolvedReportStatus(status);
          return resolved ? isResolved : !isResolved;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.cleaning_services_outlined,
            title: resolved
                ? 'No resolved reports yet.'
                : "You haven't reported any issues yet. Help keep the community clean!",
            subtitle: resolved
                ? 'Resolved reports will appear here once MENRO completes the action.'
                : 'Tap the button below to file your first report.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            final category = (data['category'] as String?)?.trim() ?? '';
            final status = (data['status'] as String?)?.trim() ?? '';
            final location = (data['location'] as String?)?.trim() ?? '';
            final submittedAt = _safeTimestampToDate(data['submittedAt']);

            final chip = _reportsChip(status);

            final rawHistory = data['statusHistory'];
            final history = rawHistory is List ? rawHistory : const [];
            final latestMessage = history.isNotEmpty
                ? ((history.last as Map?)?['message'] as String?)?.trim() ?? ''
                : '';
            final hasMenroUpdate = latestMessage.isNotEmpty;

            final locOrDate = (location.isNotEmpty)
                ? location
                : 'Submitted • ${_formatShortDate(submittedAt)}';

            final displayMid = location.isNotEmpty
                ? (submittedAt == null
                      ? location
                      : '$location • ${_formatShortDate(submittedAt)}')
                : '—';

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
                        builder: (_) => ReportDetailsScreen(reportId: doc.id),
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
                                category.isEmpty ? 'Uncategorized' : category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                        Text(
                          displayMid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Spacer(),
                            Icon(
                              hasMenroUpdate
                                  ? Icons.message_outlined
                                  : Icons.notifications_none_outlined,
                              size: 18,
                              color: hasMenroUpdate
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ],
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
          final status = (doc.data()['status'] as String?)?.trim() ?? '';
          final normalized = status.toLowerCase().trim();
          final isResolved =
              normalized == 'approved_by_denr' ||
              normalized == 'approved_by_denr' ||
              normalized == 'approved' ||
              normalized == 'resolved' ||
              normalized == 'denr approved';
          return resolved ? isResolved : !isResolved;
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.note_alt_outlined,
            title:
                'No ${resolved ? 'resolved' : 'active'} permit applications.',
            subtitle: 'Tap below to start a new request.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
            final chip = _permitChip(status);

            final justification =
                (data['reasonForRequest'] as String?)?.trim() ?? '';

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
                            style: TextStyle(
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
            'Please sign in to view your submissions.',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
      );
    }

    // New system flow: two hubs inside same screen using tabs.
    // Tabs: Active (reports + permits) and Resolved (reports + permits)
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
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            );
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('New Report'),
        ),
        body: TabBarView(
          children: [
            // Active: show violation reports + active permits in same scroll view
            _buildCompositeHub(currentUserId: currentUserId, resolved: false),
            // Resolved
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Tree Cutting Permits',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              SizedBox(
                height: 420,
                child: _treePermitsTab(
                  resolved: resolved,
                  currentUserId: currentUserId,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
