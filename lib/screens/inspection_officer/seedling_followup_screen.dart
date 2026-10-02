import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';

class SeedlingFollowUpScreen extends StatelessWidget {
  final String caseId;
  final String caseTitle;
  final int seedlingsRequired;

  const SeedlingFollowUpScreen({
    super.key,
    required this.caseId,
    required this.caseTitle,
    required this.seedlingsRequired,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in to manage follow-ups.')));
    }

    final followUps = FirebaseFirestore.instance
        .collection('case_documentation')
        .doc(caseId)
        .collection('seedling_followups')
        .snapshots(includeMetadataChanges: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seedling Follow-up'),
        backgroundColor: AppColors.primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFollowUp(context, user),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Planting'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: followUps,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load follow-ups: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) => _date(b.data()['visitDate']).compareTo(_date(a.data()['visitDate'])));
          final planted = docs.fold<int>(
            0,
            (totalPlanted, doc) =>
                totalPlanted + ((doc.data()['seedlingsPlanted'] as num?)?.toInt() ?? 0),
          );
          final remaining = (seedlingsRequired - planted).clamp(0, seedlingsRequired);

          return Column(
            children: [
              if (snapshot.data!.metadata.isFromCache ||
                  snapshot.data!.metadata.hasPendingWrites)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    snapshot.data!.metadata.hasPendingWrites
                        ? 'Follow-up record is waiting to sync.'
                        : 'Showing cached follow-up records.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caseTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Seedlings planted: $planted / $seedlingsRequired'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: seedlingsRequired <= 0
                            ? 0
                            : (planted / seedlingsRequired).clamp(0.0, 1.0),
                        color: AppColors.primary,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 6),
                      Text('$remaining remaining', style: const TextStyle(color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('No planting visits recorded yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.nature_outlined, color: AppColors.primary),
                              ),
                              title: Text('${data['seedlingsPlanted'] ?? 0} seedlings recorded'),
                              subtitle: Text(
                                '${_formatDate(_date(data['visitDate']))}\n'
                                '${data['notes'] ?? 'No notes'}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addFollowUp(
    BuildContext context,
    dynamic user,
  ) async {
    final existing = await FirebaseFirestore.instance
        .collection('case_documentation')
        .doc(caseId)
        .collection('seedling_followups')
        .get();
    if (!context.mounted) return;
    final planted = existing.docs.fold<int>(
      0,
      (totalPlanted, doc) =>
          totalPlanted + ((doc.data()['seedlingsPlanted'] as num?)?.toInt() ?? 0),
    );
    final remaining = (seedlingsRequired - planted).clamp(0, seedlingsRequired);
    if (remaining == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The seedling target is already complete.')),
      );
      return;
    }
    final countController = TextEditingController();
    final notesController = TextEditingController();
    var visitDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Planting Visit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Seedlings planted this visit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Visit notes',
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: visitDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (selected != null) setDialogState(() => visitDate = selected);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_formatDate(visitDate)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save Visit'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      countController.dispose();
      notesController.dispose();
      return;
    }
    if (confirmed == true) {
      final count = int.tryParse(countController.text.trim()) ?? 0;
      if (count <= 0 || count > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a count from 1 to $remaining.')),
        );
      } else {
        try {
          await context.read<InspectionProvider>().addSeedlingFollowUp(
                caseId: caseId,
                caseTitle: caseTitle,
                actingUser: user,
                seedlingsPlanted: count,
                visitDate: visitDate,
                notes: notesController.text.trim(),
              );
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save planting visit: $error')),
            );
          }
        }
      }
    }
    countController.dispose();
    notesController.dispose();
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Date unavailable';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
