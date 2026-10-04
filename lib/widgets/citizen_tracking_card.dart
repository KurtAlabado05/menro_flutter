import 'dart:async';

import 'package:flutter/material.dart';

class CitizenTrackingCard extends StatefulWidget {
  final String transactionNumber;
  final String serviceName;
  final String currentWorkflowTier;
  final bool isSlaBreached;
  final DateTime? targetSlaCompletionDate;
  final String status;
  final List<Map<String, dynamic>> dynamicChecklistAttachments;

  // Admin-determined severity (citizen never sets this)
  final String? severityStatus;
  final dynamic severity;

  const CitizenTrackingCard({
    super.key,
    required this.transactionNumber,
    required this.serviceName,
    required this.currentWorkflowTier,
    required this.isSlaBreached,
    required this.targetSlaCompletionDate,
    required this.status,
    required this.dynamicChecklistAttachments,
    this.severityStatus,
    this.severity,
  });

  @override
  State<CitizenTrackingCard> createState() => _CitizenTrackingCardState();
}

class _CitizenTrackingCardState extends State<CitizenTrackingCard> {
  late final Timer _timer;
  late DateTime _now;

  Widget _SeverityLine({required String? severityStatus}) {
    final normalized = severityStatus?.trim();
    final text = (normalized == null || normalized.isEmpty)
        ? 'Urgency / Severity: Pending technical evaluation'
        : (normalized == 'Pending Admin Assessment'
            ? 'Urgency / Severity: Pending technical evaluation'
            : 'Urgency / Severity: $normalized');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.black87,
          fontSize: 13,
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _workflowLabel(String tier) {
    switch (tier) {
      case 'ReceivingClerk':
        return 'Receiving Desk (LGU Intake)';
      case 'TechnicalActionOfficer':
        return 'Technical Evaluation & Inspection';
      case 'CenroChief':
        return 'MENRO Officer Approval';
      default:
        return 'Processing Queue';
    }
  }

  String _countdownText(DateTime now, DateTime target) {
    final diff = target.difference(now);
    if (diff.isNegative) return '0d 0h remaining';

    final totalHours = diff.inHours;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;

    return '${days}d ${hours}h remaining';
  }

  @override
  Widget build(BuildContext context) {
    final workflowLabel = _workflowLabel(widget.currentWorkflowTier);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Card Header & Core Details
            Text(
              widget.transactionNumber.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              widget.serviceName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),

            Text(
              workflowLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _StatusBadge(status: widget.status),
            const SizedBox(height: 10),

            _SeverityLine(
              severityStatus: null,
            ),
            const SizedBox(height: 14),


            // B. Dynamic SLA Timer Widget
            if (widget.isSlaBreached)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🚨 SLA Overdue (Escalated to Supervisor)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Builder(builder: (context) {
                final target = widget.targetSlaCompletionDate;
                final countdown = (target == null)
                    ? 'SLA time not available'
                    : _countdownText(_now, target);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    countdown,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                );
              }),

            const SizedBox(height: 14),

            // C. Expandable Itemized Checklist Progress
            ExpansionTile(
              title: const Text(
                'View Required Document Checklist',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              children: [
                if (widget.dynamicChecklistAttachments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No checklist data available.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  ...widget.dynamicChecklistAttachments.map((item) {
                    final requirementName =
                        (item['requirementName'] as String?)?.trim() ?? '';
                    final isVerified = item['isVerified'] is bool
                        ? item['isVerified'] as bool
                        : false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isVerified ? Icons.check_circle : Icons.hourglass_empty,
                            size: 18,
                            color: isVerified ? Colors.green : Colors.amber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  requirementName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!isVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Text(
                                      'Awaiting manual verification by Clerk',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final text = status.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

