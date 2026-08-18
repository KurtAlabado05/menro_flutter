import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../submissions/my_submissions_screen.dart';
import '../tree_cutting_application_screen.dart';
import '../transaction/transaction_submission_form.dart';

class GovernmentServicesHubScreen extends StatelessWidget {
  const GovernmentServicesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Government Services')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tree Cutting Permit Application',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Submit your tree cutting permit application and track your verification progress through the LGU workflow.',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.eco_outlined),
                label: const Text('Apply for Tree Cutting Permit'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
MaterialPageRoute(
                      builder: (_) => const TreeCuttingApplicationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.track_changes_outlined),
                label: const Text('Track My Permit Applications'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.statusVerified,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MySubmissionsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

