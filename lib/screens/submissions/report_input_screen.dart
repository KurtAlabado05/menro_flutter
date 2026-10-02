import 'package:flutter/material.dart';

import '../report/report_screen.dart';

/// Hosts the report form under a standard app bar.
class ReportInputScreen extends StatelessWidget {
  const ReportInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Environmental Report Form')),
      body: const ReportScreen(),
    );
  }
}
