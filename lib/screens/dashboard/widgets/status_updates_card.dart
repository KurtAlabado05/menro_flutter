import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../core/constants/status_config.dart';
import '../../../widgets/section_widgets.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../report/report_details_screen.dart';
import '../../tree_cutting_permit_details_screen.dart';

enum _UpdateKind { report, permit }

class _StatusUpdate {
  const _StatusUpdate({
    required this.kind,
    required this.id,
    required this.status,
    required this.message,
    required this.timestamp,
  });

  final _UpdateKind kind;
  final String id;
  final String status;
  final String message;
  final DateTime? timestamp;
}

/// Latest status change across the user's reports and tree-cutting permits.
class StatusUpdatesCard extends StatefulWidget {
  const StatusUpdatesCard({super.key, required this.userId});

  final String userId;

  @override
  State<StatusUpdatesCard> createState() => _StatusUpdatesCardState();
}

class _StatusUpdatesCardState extends State<StatusUpdatesCard> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _permitsStream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(StatusUpdatesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _subscribe();
  }

  void _subscribe() {
    final db = FirebaseFirestore.instance;
    _reportsStream = db
        .collection('reports')
        .where('submittedBy', isEqualTo: widget.userId)
        .snapshots();
    _permitsStream = db
        .collection('tree_cutting_permits')
        .where('submittedByUid', isEqualTo: widget.userId)
        .snapshots();
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<_StatusUpdate> _collect(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    _UpdateKind kind,
  ) {
    final updates = <_StatusUpdate>[];
    for (final doc in snapshot?.docs ?? const []) {
      final history = doc.data()['statusHistory'];
      if (history is! List || history.isEmpty) continue;
      final latest = history.last;
      if (latest is! Map) continue;
      final status = latest['status']?.toString().trim() ?? '';
      updates.add(
        _StatusUpdate(
          kind: kind,
          id: doc.id,
          status: status.isEmpty ? 'pending' : status,
          message: latest['message']?.toString().trim() ?? '',
          timestamp: _toDate(latest['timestamp']),
        ),
      );
    }
    return updates;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inDays >= 7) {
      final year = local.year == DateTime.now().year ? '' : ', ${local.year}';
      return '${_months[local.month - 1]} ${local.day}$year';
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _open(_StatusUpdate update) {
    final Widget screen = update.kind == _UpdateKind.report
        ? ReportDetailsScreen(reportId: update.id)
        : TreeCuttingPermitDetailsScreen(permitId: update.id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _permitsStream,
      builder: (context, permits) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reportsStream,
          builder: (context, reports) {
            if (permits.hasError || reports.hasError) {
              return SectionCard(child: _buildError());
            }
            if (!permits.hasData || !reports.hasData) {
              return const SectionCard(child: _Loading());
            }

            final updates = [
              ..._collect(reports.data, _UpdateKind.report),
              ..._collect(permits.data, _UpdateKind.permit),
            ];
            updates.sort((a, b) {
              if (a.timestamp == null && b.timestamp == null) return 0;
              if (a.timestamp == null) return 1;
              if (b.timestamp == null) return -1;
              return b.timestamp!.compareTo(a.timestamp!);
            });

            return SectionCard(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Updates',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (updates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text(
                        'No updates yet. Submit a report or apply for a permit to see progress here.',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    )
                  else
                    for (final update in updates.take(5))
                      _UpdateTile(
                        update: update,
                        dateText: _formatDate(update.timestamp),
                        onTap: () => _open(update),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.textGrey),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Could not load status updates.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => setState(_subscribe),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading status updates',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 16),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 38, radius: AppRadius.md),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 38, radius: AppRadius.md),
        ],
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({
    required this.update,
    required this.dateText,
    required this.onTap,
  });

  final _StatusUpdate update;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = StatusConfig.fromStatus(update.status);
    final isReport = update.kind == _UpdateKind.report;
    final kindLabel = isReport ? 'Report' : 'Permit';
    final message = update.message.isNotEmpty
        ? update.message
        : 'No message provided';

    return Semantics(
      button: true,
      label: '$kindLabel ${config.label}. $message. $dateText',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: config.color.fade(0.12),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(config.icon, color: config.color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: config.color,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: (isReport ? Colors.orange : Colors.blue).fade(
                          0.12,
                        ),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        kindLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isReport
                              ? Colors.orange.shade900
                              : Colors.blue.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
