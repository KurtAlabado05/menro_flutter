import 'package:flutter/material.dart';

import 'report_submissions_hub_screen.dart';

import '../report/report_screen.dart';

/// A dedicated wrapper for the report input form.
/// Adds the required header:
/// - “Environmental Report Complaint Form”
/// - Back button returning to [ReportSubmissionsHubScreen].
class ReportInputScreen extends StatelessWidget {
  const ReportInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text(
          'Environmental Report Form',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: const ReportScreen(),
    );
  }
}
