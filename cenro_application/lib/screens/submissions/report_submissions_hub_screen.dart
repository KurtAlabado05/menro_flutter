import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/status_config.dart'; // 🟢 IMPORTED CENTRALIZED STATUS CONFIG
import '../../screens/report/report_details_screen.dart';
import '../../widgets/empty_state.dart';
import 'report_input_screen.dart';

class ReportSubmissionsHubScreen extends StatefulWidget {
  const ReportSubmissionsHubScreen({super.key});

  @override
  State<ReportSubmissionsHubScreen> createState() =>
      _ReportSubmissionsHubScreenState();
}

class _ReportSubmissionsHubScreenState
    extends State<ReportSubmissionsHubScreen> {
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
    return dt.toLocal().toString().split('.').first;
  }

  Widget _buildReportsTab({
    required bool resolved,
    required String currentUserId,
  }) {
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
          // 🟢 REMOVED TOP WHITE GAP GAP AND PROVIDED CLEARANCE FOR THE FLOATING ACTION BUTTON AT THE BOTTOM
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 88,
            left: 16,
            right: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            final category = (data['category'] as String?)?.trim() ?? '';
            final status = (data['status'] as String?)?.trim() ?? '';
            final location = (data['location'] as String?)?.trim() ?? '';
            final submittedAt = _safeTimestampToDate(data['submittedAt']);

            final rawHistory = data['statusHistory'];
            final history = rawHistory is List ? rawHistory : const [];
            final latestMessage = history.isNotEmpty
                ? ((history.last as Map?)?['message'] as String?)?.trim() ?? ''
                : '';
            final hasMenroUpdate = latestMessage.isNotEmpty;

            final displayMid = location.isNotEmpty
                ? (submittedAt == null
                      ? location
                      : '$location • ${_formatShortDate(submittedAt)}')
                : '—';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
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
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 🟢 REPLACED LOCAL WIDGET CHIP ENGINE WITH UNIFIED STATUS CONFIG BADGE
                            StatusConfig.buildBadge(status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          displayMid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null || currentUserId.trim().isEmpty) {
      // 🟢 REMOVED EXPLICIT 'const' FROM SCAFFOLD TO AVOID CONSTANT BOUNDARY ERRORS WITH APPCOLORS
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Please sign in to view your report submissions.',
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
            _buildReportsTab(resolved: false, currentUserId: currentUserId),
            _buildReportsTab(resolved: true, currentUserId: currentUserId),
          ],
        ),
      ),
    );
  }
}
