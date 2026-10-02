import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Status configuration for reports and tree cutting permits
/// Workflow: submitted/pending -> inspection_in_progress -> forwarded_to_denr -> approved_by_denr -> resolved
class StatusConfig {
  final String statusKey;
  final String label;
  final Color color;
  final IconData icon;
  final String description;

  const StatusConfig({
    required this.statusKey,
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
  });

  /// Get status configuration by status string
  static StatusConfig fromStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      return _pending;
    }

    final normalizedStatus = status.toLowerCase().trim().replaceAll('_', ' ');

    switch (normalizedStatus) {
      case 'submitted':
      case 'pending':
        return _pending;
      case 'inspection_in_progress':
      case 'inspection in progress':
      case 'under inspection':
      case 'inspecting':
      case 'forwarded_to_inspection_officer':
      case 'forwarded to inspection officer':
      case 'inspection officer':
        return _inspectionInProgress;
      case 'forwarded_to_denr':
      case 'forwarded to denr':
      case 'forwarded_to_denr_officer':
      case 'forwarded to denr officer':
      case 'for denr review':
      case 'denr review':
        return _forwardedToDENR;
      case 'approved_by_denr':
      case 'approved by denr':
      case 'denr approved':
      case 'approved':
        return _approvedByDENR;
      case 'resolved':
        return _resolved;
      case 'verified':
        return _verified;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'denied':
        return _rejected;
      case 'on_hold':
      case 'on hold':
        return _onHold;
      default:
        // Return a default config for unknown statuses
        return StatusConfig(
          statusKey: status,
          label: _toTitleCase(status),
          color: AppColors.textGrey,
          icon: Icons.help_outline,
          description: 'Status: $status',
        );
    }
  }

  /// Get color for a status string
  static Color getColor(String? status) {
    return fromStatus(status).color;
  }

  /// Get label for a status string
  static String getLabel(String? status) {
    return fromStatus(status).label;
  }

  /// Get icon for a status string
  static IconData getIcon(String? status) {
    return fromStatus(status).icon;
  }

  // Predefined status configurations (private to avoid naming conflicts)
  static const _pending = StatusConfig(
    statusKey: 'pending',
    label: 'Pending',
    color: AppColors.statusPending,
    icon: Icons.schedule,
    description: 'Awaiting clerk review',
  );

  static const _inspectionInProgress = StatusConfig(
    statusKey: 'inspection_in_progress',
    label: 'Under Inspection',
    color: AppColors.statusInspection,
    icon: Icons.search_outlined,
    description: 'Inspector is reviewing the submission',
  );

  static const _forwardedToDENR = StatusConfig(
    statusKey: 'forwarded_to_denr',
    label: 'For DENR Review',
    color: AppColors.statusForwarded,
    icon: Icons.forward_outlined,
    description: 'Forwarded to DENR for approval',
  );

  static const _approvedByDENR = StatusConfig(
    statusKey: 'approved_by_denr',
    label: 'DENR Approved',
    color: AppColors.statusApproved,
    icon: Icons.approval_outlined,
    description: 'Approved by DENR',
  );

  static const _resolved = StatusConfig(
    statusKey: 'resolved',
    label: 'Resolved',
    color: AppColors.statusResolved,
    icon: Icons.check_circle_outline,
    description: 'Issue has been fully resolved',
  );

  static const _verified = StatusConfig(
    statusKey: 'verified',
    label: 'Verified',
    color: AppColors.statusVerified,
    icon: Icons.verified_outlined,
    description: 'Submission has been verified',
  );

  static const _rejected = StatusConfig(
    statusKey: 'rejected',
    label: 'Rejected',
    color: AppColors.statusRejected,
    icon: Icons.cancel_outlined,
    description: 'Submission has been rejected',
  );

  static const _onHold = StatusConfig(
    statusKey: 'on_hold',
    label: 'On Hold',
    color: AppColors.statusCancelled,
    icon: Icons.pause_circle_outline,
    description: 'Processing is temporarily paused',
  );

  /// Get the workflow order/priority of a status
  static int getWorkflowOrder(String? status) {
    if (status == null || status.trim().isEmpty) return 0;

    final normalizedStatus = status.toLowerCase().trim().replaceAll('_', ' ');

    switch (normalizedStatus) {
      case 'submitted':
      case 'pending':
        return 1;
      case 'inspection_in_progress':
      case 'inspection in progress':
      case 'under inspection':
        return 2;
      case 'forwarded_to_denr':
      case 'forwarded to denr':
      case 'for denr review':
        return 3;
      case 'approved_by_denr':
      case 'approved by denr':
      case 'denr approved':
        return 4;
      case 'verified':
        return 5;
      case 'resolved':
        return 6;
      case 'rejected':
      case 'cancelled':
      case 'denied':
        return -1;
      case 'on_hold':
      case 'on hold':
        return 0;
      default:
        return 0;
    }
  }

  /// Check if a status is a final/completed status
  static bool isCompletedStatus(String? status) {
    if (status == null || status.trim().isEmpty) return false;
    final normalizedStatus = status.toLowerCase().trim().replaceAll('_', ' ');
    return normalizedStatus == 'resolved' ||
        normalizedStatus == 'verified' ||
        normalizedStatus == 'approved_by_denr' ||
        normalizedStatus == 'approved by denr' ||
        normalizedStatus == 'denr approved';
  }

  /// Check if a status is a rejected/cancelled status
  static bool isRejectedStatus(String? status) {
    if (status == null || status.trim().isEmpty) return false;
    final normalizedStatus = status.toLowerCase().trim().replaceAll('_', ' ');
    return normalizedStatus == 'rejected' ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled' ||
        normalizedStatus == 'denied';
  }

  /// Convert a string to Title Case
  static String _toTitleCase(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Get all workflow statuses in order
  static List<StatusConfig> getWorkflowStatuses() {
    return [
      _pending,
      _inspectionInProgress,
      _forwardedToDENR,
      _approvedByDENR,
      _resolved,
    ];
  }

  /// Build a status badge widget with consistent styling
  static Widget buildBadge(String? status) {
    final config = fromStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
