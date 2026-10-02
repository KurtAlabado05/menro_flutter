import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'case_documentation_detail_screen.dart';
import '../auth/login_screen.dart';

class DenrCaseQueueScreen extends StatelessWidget {
  const DenrCaseQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = FirebaseFirestore.instance
        .collection('case_documentation')
        .where('status', isEqualTo: 'forwarded_to_denr_officer')
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cases for DENR Review'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cases,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load forwarded cases: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => _date(
                b.data()['forwardedAt'],
              ).compareTo(_date(a.data()['forwardedAt'])),
            );
          if (documents.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No cases for DENR review',
              subtitle:
                  'Inspection cases forwarded by the Inspection Officer will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final document = documents[index];
              final record = document.data();
              final isTreeCase =
                  record['caseType'] == 'tree_cutting_inspection';
              return Card(
                elevation: 0,
                color: AppColors.cardWhite,
                child: ListTile(
                  leading: Icon(
                    isTreeCase ? Icons.park_outlined : Icons.eco_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    (record['title'] ?? 'Inspection case').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${isTreeCase ? 'Tree cutting inspection' : 'Environmental report'} · '
                    '${record['siteAddress'] ?? 'Site not specified'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const StatusBadge(
                    status: 'forwarded_to_denr_officer',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CaseDocumentationDetailScreen(
                        caseId: document.id,
                        record: record,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
