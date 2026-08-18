import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/status_config.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../report/report_details_screen.dart';
import '../submissions/report_input_screen.dart';
import '../tree_cutting_application_screen.dart';
import '../tree_cutting/tree_cutting_justification_guidelines_screen.dart';
import '../submissions/my_submissions_screen.dart';
import '../tree_cutting_permit_details_screen.dart';
import '../project/project_list_wrapper_screen.dart';

import 'ordinances_screen.dart';
import '../../widgets/empty_state.dart';

class DashboardScreen extends StatefulWidget {
  final ScrollController scrollController;
  const DashboardScreen({super.key, required this.scrollController});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isMetricsLoading = true;

  int _pendingReports = 0;
  int _pendingPermits = 0;

  // Checklist State Variables
  bool _step1Authority = false;
  bool _step2Documents = false;
  bool _step3Photos = false;

  DateTime? _safeTimestampToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '—';
    return dt.toLocal().toString().split('.').first;
  }

  ({String status, String message, DateTime? timestamp, String? updatedBy})
  _extractLatestStatus(dynamic statusHistoryItem) {
    if (statusHistoryItem is! Map) {
      return (status: 'pending', message: '', timestamp: null, updatedBy: null);
    }
    final map = statusHistoryItem;

    final status = map['status']?.toString().trim().isNotEmpty == true
        ? map['status'].toString().trim()
        : 'pending';
    final message = map['message']?.toString().trim() ?? '';
    final updatedBy = map['updatedBy'] == null
        ? null
        : map['updatedBy'].toString();
    final timestamp = _safeTimestampToDate(map['timestamp']);

    return (
      status: status,
      message: message,
      timestamp: timestamp,
      updatedBy: updatedBy,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadFeed();
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        _loadUserScopedMetrics(auth.user!.id, auth.user!.role);
      }
    });
  }

  Future<void> _loadUserScopedMetrics(String userId, String role) async {
    if (!mounted) return;
    setState(() => _isMetricsLoading = true);
    try {
      Query reportsQuery = FirebaseFirestore.instance.collection('reports');
      Query permitsQuery = FirebaseFirestore.instance.collection(
        'tree_cutting_permits',
      );

      if (role != 'admin') {
        reportsQuery = reportsQuery.where('submittedByUid', isEqualTo: userId);
        permitsQuery = permitsQuery.where('submittedByUid', isEqualTo: userId);
      }

      final rSnap = await reportsQuery
          .where('status', isEqualTo: 'pending')
          .get();
      final pSnap = await permitsQuery
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        setState(() {
          _pendingReports = rSnap.size;
          _pendingPermits = pSnap.size;
        });
      }
    } catch (e) {
      debugPrint('Metrics load failed: $e');
    } finally {
      if (mounted) setState(() => _isMetricsLoading = false);
    }
  }

  // --- UI Components ---
  Widget _buildOrdinanceHeroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Local Ordinances',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdinancesScreen()),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/ordinances/follow_environmental_rules.png',
                    fit: BoxFit.fitWidth,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.primary.withOpacity(0.05),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.policy_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tap to view all local ordinances',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveGuide() {
    int completedSteps = [
      _step1Authority,
      _step2Documents,
      _step3Photos,
    ].where((step) => step).length;

    double progress = completedSteps / 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Application Readiness',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? Colors.green : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : AppColors.primary,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Complete before applying:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildChecklistItem(
            'Step 1: Choose recipient authority — LGU or DENR-CENRO',
            _step1Authority,
            (val) => setState(() => _step1Authority = val ?? false),
          ),
          _buildChecklistItem(
            'Step 2: Upload Section B documents — Request Letter + LGU/Barangay No Objection',
            _step2Documents,
            (val) => setState(() => _step2Documents = val ?? false),
          ),
          _buildChecklistItem(
            'Step 3: Attach tree target photos (field photographs).',
            _step3Photos,
            (val) => setState(() => _step3Photos = val ?? false),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const TreeCuttingJustificationGuidelinesScreen(),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_ios, size: 14),
              label: const Text(
                'Learn more',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
    String text,
    bool isChecked,
    Function(bool?) onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!isChecked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              isChecked ? Icons.check_circle : Icons.circle_outlined,
              color: isChecked ? Colors.green : Colors.grey.shade400,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isChecked ? Colors.grey.shade600 : Colors.black87,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHub(BuildContext context, String currentUserId) {
    final reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('submittedBy', isEqualTo: currentUserId)
        .snapshots();

    final permitsStream = FirebaseFirestore.instance
        .collection('tree_cutting_permits')
        .where('submittedByUid', isEqualTo: currentUserId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: permitsStream,
      builder: (context, permitSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: reportsStream,
          builder: (context, reportSnapshot) {
            if (permitSnapshot.hasError || reportSnapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Failed to load status updates',
                subtitle:
                    '${permitSnapshot.error ?? ''} ${reportSnapshot.error ?? ''}'
                        .trim(),
                actionLabel: 'Retry',
                onAction: () => setState(() {}),
              );
            }

            if (permitSnapshot.connectionState == ConnectionState.waiting ||
                reportSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              );
            }

            final permitDocs = permitSnapshot.data?.docs ?? [];
            final reportDocs = reportSnapshot.data?.docs ?? [];
            final updates = <Map<String, dynamic>>[];

            for (final doc in reportDocs) {
              final data = doc.data();
              final rawHistory = data['statusHistory'];
              final history = rawHistory is List ? rawHistory : const [];
              if (history.isEmpty) continue;

              final latestItem = history.last;
              final latest = _extractLatestStatus(latestItem);

              updates.add({
                'type': 'report',
                'id': doc.id,
                'status': latest.status,
                'message': latest.message,
                'timestamp': latest.timestamp,
                'updatedBy': latest.updatedBy,
              });
            }

            for (final doc in permitDocs) {
              final data = doc.data();
              final rawHistory = data['statusHistory'];
              final history = rawHistory is List ? rawHistory : const [];
              if (history.isEmpty) continue;

              final latestItem = history.last;
              final latest = _extractLatestStatus(latestItem);

              updates.add({
                'type': 'permit',
                'id': doc.id,
                'status': latest.status,
                'message': latest.message,
                'timestamp': latest.timestamp,
                'updatedBy': latest.updatedBy,
              });
            }

            updates.sort((a, b) {
              final ta = a['timestamp'] as DateTime?;
              final tb = b['timestamp'] as DateTime?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });

            final shown = updates.take(6).toList();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Updates',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No updates yet. Submit a report or apply for a permit to see progress here.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final u = shown[index];
                        final type = u['type']?.toString() ?? 'report';
                        final status = u['status']?.toString();
                        final message = u['message']?.toString().trim() ?? '';
                        final timestamp = u['timestamp'] as DateTime?;
                        final config = StatusConfig.fromStatus(status);

                        // Dynamic badge colors depending on the update type
                        final isReport = type == 'report';
                        final badgeBgColor = isReport
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1);
                        final badgeTextColor = isReport
                            ? Colors.orange.shade800
                            : Colors.blue.shade800;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final id = u['id']?.toString() ?? '';
                            if (isReport) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailsScreen(reportId: id),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TreeCuttingPermitDetailsScreen(
                                        permitId: id,
                                      ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left Status Icon Indicator
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: config.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: config.color.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Icon(
                                    config.icon,
                                    color: config.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Center Context (Expanded to take up all middle space)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        config.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: config.color,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message.isNotEmpty
                                            ? message
                                            : 'No message provided',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Far Right Actions / Metadata Hub
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Clean Type Badge Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBgColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: badgeTextColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Short Date Display
                                    Text(
                                      _formatShortDate(timestamp),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCitizenDashboard(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildOrdinanceHeroBanner(context),
        const SizedBox(height: 14),
        _buildStatusHub(context, FirebaseAuth.instance.currentUser?.uid ?? ''),
        const SizedBox(height: 20),
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _quickActionCard(
              'Report Issue',
              Icons.campaign_outlined,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportInputScreen()),
              ),
              badgeCount: _pendingReports,
            ),
            const SizedBox(width: 12),
            _quickActionCard(
              'Apply Permit',
              Icons.note_add_outlined,
              AppColors.primary,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TreeCuttingApplicationScreen(),
                ),
              ),
              badgeCount: _pendingPermits,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _quickActionCard(
              'Join Projects',
              Icons.nature_people_outlined,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProjectListWrapperScreen(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 20),
        _buildInteractiveGuide(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _quickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 28),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final firstName = user?.name.split(' ').first ?? 'User';
        final isOrg = user?.role == 'organization';

        return SingleChildScrollView(
          controller: widget.scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isOrg
                ? const SizedBox.shrink()
                : _buildCitizenDashboard(firstName),
          ),
        );
      },
    );
  }
}
