import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/user_roles.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import 'seedling_followup_screen.dart';

class CaseDocumentationDetailScreen extends StatelessWidget {
  final String caseId;
  final Map<String, dynamic> record;

  const CaseDocumentationDetailScreen({
    super.key,
    required this.caseId,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final status = (record['status'] ?? 'draft').toString();
    final canForward =
        user?.role == UserRoles.inspectionOfficer &&
        status == 'submitted' &&
        (record['linkedApplicationId']?.toString().isNotEmpty ?? false) &&
        {
          'applications',
          'tree_cutting_permits',
          'reports',
        }.contains(record['linkedApplicationCollection']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Case Documentation'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            (record['title'] ?? 'Inspection case').toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${_caseTypeLabel((record['caseType'] ?? '').toString())} · ${status.toUpperCase()}',
            style: const TextStyle(color: AppColors.textGrey),
          ),
          if (record['caseType'] == 'tree_cutting_inspection' &&
              status == 'submitted' &&
              ((record['seedlingsRequired'] as num?)?.toInt() ?? 0) > 0) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SeedlingFollowUpScreen(
                      caseId: caseId,
                      caseTitle: (record['title'] ?? 'Tree inspection')
                          .toString(),
                      seedlingsRequired: (record['seedlingsRequired'] as num)
                          .toInt(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.nature_outlined),
                label: const Text('Seedling Follow-up'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _section('Inspection Findings', [
            _detail('Findings', record['findings']),
            _detail('Severity', record['severity']),
            _detail('Urgency', record['urgency']),
            _detail('Site address', record['siteAddress']),
            _detail('Barangay', record['barangay']),
            _detail('Inspector', record['inspectorName']),
            _detail('Officer attestation', record['officerAttestation']),
            if ((record['caseType'] ?? '') == 'tree_cutting_inspection') ...[
              _detail('Trees inspected', record['treeCount']),
              _detail('Action', record['treeActionType']),
              _detail('Seedlings required', record['seedlingsRequired']),
            ],
            _detail(
              'Coordinates',
              record['latitude'] == null || record['longitude'] == null
                  ? null
                  : '${record['latitude']}, ${record['longitude']}',
            ),
          ]),
          const SizedBox(height: 16),
          _LinkedSubmissionSection(
            collection: record['linkedApplicationCollection']?.toString(),
            documentId: record['linkedApplicationId']?.toString(),
          ),
          if (record['checklistResponses'] is Map) ...[
            const SizedBox(height: 16),
            _section(
              'Inspection Checklist',
              (record['checklistResponses'] as Map).entries
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        entry.value == true
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        color: entry.value == true
                            ? AppColors.primary
                            : AppColors.textGrey,
                      ),
                      title: Text(entry.key.toString()),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (record['photos'] is List &&
              (record['photos'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            _section(
              'Field Photos',
              (record['photos'] as List).whereType<Map>().map((photo) {
                final data = Map<String, dynamic>.from(photo);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_outlined),
                  title: Text(
                    (data['name'] ?? data['phase'] ?? 'Photo').toString(),
                  ),
                  subtitle: Text((data['caption'] ?? '').toString()),
                  trailing: (data['url'] ?? '').toString().isEmpty
                      ? null
                      : Image.network(
                          data['url'].toString(),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                );
              }).toList(),
            ),
          ],
          if (record['files'] is List &&
              (record['files'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            _section(
              'Attached Files',
              (record['files'] as List).whereType<Map>().map((file) {
                final data = Map<String, dynamic>.from(file);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text((data['name'] ?? 'File').toString()),
                  subtitle: SelectableText((data['url'] ?? '').toString()),
                );
              }).toList(),
            ),
          ],
          if (record['activityHistory'] is List) ...[
            const SizedBox(height: 16),
            _section(
              'Case History',
              (record['activityHistory'] as List).whereType<Map>().map((event) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, color: AppColors.primary),
                  title: Text((event['event'] ?? 'Updated').toString()),
                  subtitle: Text(
                    '${event['actorName'] ?? 'Officer'} · ${event['at'] ?? ''}',
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      bottomNavigationBar: canForward
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: _ForwardCaseButton(
                caseId: caseId,
                record: record,
                user: user!,
              ),
            )
          : null,
    );
  }

  static String _caseTypeLabel(String type) => switch (type) {
    'tree_cutting_inspection' => 'Tree Cutting Inspection',
    _ => 'Environmental Report',
  };

  static Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  static Widget _detail(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
          const SizedBox(height: 2),
          Text(text),
        ],
      ),
    );
  }
}

class _LinkedSubmissionSection extends StatelessWidget {
  final String? collection;
  final String? documentId;

  const _LinkedSubmissionSection({this.collection, this.documentId});

  @override
  Widget build(BuildContext context) {
    if (collection == null ||
        documentId == null ||
        !{
          'applications',
          'tree_cutting_permits',
          'reports',
        }.contains(collection)) {
      return CaseDocumentationDetailScreen._section('Linked Submission', [
        const Text('No application or environmental report is linked.'),
      ]);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection!)
          .doc(documentId!)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CaseDocumentationDetailScreen._section('Linked Submission', [
            const Text('Linked submission details could not be loaded.'),
          ]);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return CaseDocumentationDetailScreen._section('Linked Submission', [
            const Text('Linked submission is no longer available.'),
          ]);
        }
        final isReport = collection == 'reports';
        final details = <Widget>[
          CaseDocumentationDetailScreen._detail(
            'Type',
            isReport
                ? data['category'] ?? 'Environmental Report'
                : data['applicationType'] ?? data['type'],
          ),
          CaseDocumentationDetailScreen._detail(
            'Applicant',
            data['applicantName'] ?? data['submittedByName'] ?? data['name'],
          ),
          CaseDocumentationDetailScreen._detail('Status', data['status']),
          CaseDocumentationDetailScreen._detail(
            'Description',
            data['description'] ?? data['reasonForRequest'],
          ),
          CaseDocumentationDetailScreen._detail(
            'Location',
            data['location'] ?? data['applicationAddress'] ?? data['address'],
          ),
          CaseDocumentationDetailScreen._detail(
            'Tree species',
            data['species'] ?? data['kindOfTree'],
          ),
          CaseDocumentationDetailScreen._detail(
            'Tree count',
            data['numberOfTrees'],
          ),
        ];
        return CaseDocumentationDetailScreen._section(
          'Linked Submission',
          details,
        );
      },
    );
  }
}

class _ForwardCaseButton extends StatefulWidget {
  final String caseId;
  final Map<String, dynamic> record;
  final UserModel user;

  const _ForwardCaseButton({
    required this.caseId,
    required this.record,
    required this.user,
  });

  @override
  State<_ForwardCaseButton> createState() => _ForwardCaseButtonState();
}

class _ForwardCaseButtonState extends State<_ForwardCaseButton> {
  bool _forwarding = false;
  String? _error;

  Future<void> _forward() async {
    setState(() {
      _forwarding = true;
      _error = null;
    });
    try {
      await context.read<InspectionProvider>().forwardCaseDocumentationToDenr(
        caseId: widget.caseId,
        caseData: widget.record,
        actingUser: widget.user,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _forwarding = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      FilledButton.icon(
        onPressed: _forwarding ? null : _forward,
        icon: _forwarding
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.forward_to_inbox_outlined),
        label: const Text('Forward Case to DENR'),
      ),
    ],
  );
}
