import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2E7D32); // Deep Green
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color background = Color(0xFFF5F5F5); // Soft white/grey
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF212121);
  static const Color textGrey = Color(0xFF757575);

  // Status Colors - Workflow Status Progression
  // submitted/pending (on clerk) -> inspection_in_progress (on inspector) ->
  // forwarded_to_denr -> approved_by_denr -> resolved
  static const Color statusSubmitted = Color(
    0xFF2196F3,
  ); // Blue - Initial submission
  static const Color statusPending = Color(
    0xFFFFA000,
  ); // Orange - Pending clerk review
  static const Color statusInspection = Color(
    0xFF1976D2,
  ); // Blue - Inspection in Progress
  static const Color statusInspectionInProgress = Color(
    0xFF9C27B0,
  ); // Purple - Under inspection
  static const Color statusForwarded = Color(
    0xFF7B1FA2,
  ); // Purple - Forwarded to DENR
  static const Color statusForwardedToDENR = Color(
    0xFFFF9800,
  ); // Deep Orange - Forwarded to DENR
  static const Color statusApproved = Color(
    0xFF00897B,
  ); // Teal - Approved by DENR
  static const Color statusApprovedByDENR = Color(
    0xFF4CAF50,
  ); // Green - Approved by DENR
  static const Color statusResolved = Color(
    0xFF388E3C,
  ); // Green - Fully resolved
  static const Color statusVerified = Color(0xFF1976D2); // Blue - Verified
  static const Color statusRejected = Color(0xFFD32F2F); // Red - Rejected
  static const Color statusCancelled = Color(0xFF757575); // Grey - Cancelled
  static const Color statusOnHold = Color(0xFF795548); // Brown - On hold

  // Category Colors
  static const Color categoryWaste = Color(0xFFE65100);
  static const Color categoryFlooding = Color(0xFF1565C0);
  static const Color categoryPollution = Color(0xFF6A1B9A);
  static const Color categoryLogging = Color(0xFF3E2723);

  // Accent / Chart
  static const Color accentTeal = Color(0xFF00897B);
  static const Color accentBlue = Color(0xFF0288D1);
  static const Color accentCoral = Color(0xFFFF7043);
  static const Color accentLime = Color(0xFFAFB42B);

  // Surface variants
  static const Color surfaceLight = Color(0xFFF0F4F0);
}
