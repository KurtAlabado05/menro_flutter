import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'case_documentation_detail_screen.dart';
import 'case_documentation_screen.dart';
import 'seedling_followup_screen.dart';

class CaseDocumentationListScreen extends StatelessWidget {
  const CaseDocumentationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().user?.id;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view case records.')),
      );
    }

    final casesStream = FirebaseFirestore.instance
        .collection('case_documentation')
        .where('inspectorId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Case Documentation'),
        backgroundColor: AppColors.primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CaseDocumentationScreen()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Case'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: casesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load case records: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aDate = _date(a.data()['recordedAt']);
              final bDate = _date(b.data()['recordedAt']);
              return bDate.compareTo(aDate);
            });
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_outlined,
                      size: 56,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No case records yet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text('Create a record during or after a site inspection.'),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              if (snapshot.data!.metadata.isFromCache ||
                  snapshot.data!.metadata.hasPendingWrites)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    snapshot.data!.metadata.hasPendingWrites
                        ? 'Drafts or case updates are waiting to sync.'
                        : 'Showing locally cached case records.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final document = records[index];
                    final record = document.data();
                    final recordedAt = _date(record['recordedAt']);
                    final caseType = (record['caseType'] ?? '').toString();
                    final isDraft = record['status'] == 'draft';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CaseDocumentationDetailScreen(
                              caseId: document.id,
                              record: record,
                            ),
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(
                            caseType == 'tree_cutting_inspection'
                                ? Icons.park_outlined
                                : Icons.eco_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          (record['title'] ?? 'Inspection case').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_caseTypeLabel(caseType)} · ${_formatDate(recordedAt)}\n'
                          '${record['siteAddress'] ?? 'Site not specified'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDraft)
                              IconButton(
                                tooltip: 'Resume draft',
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CaseDocumentationScreen(
                                      caseId: document.id,
                                      initialRecord: record,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            IconButton(
                              tooltip: 'Quick preview',
                              onPressed: () =>
                                  _showDetails(context, record, document.id),
                              icon: const Icon(Icons.preview_outlined),
                            ),
                            _StatusChip(
                              status: (record['status'] ?? 'draft').toString(),
                            ),
                          ],
                        ),
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

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Date unavailable';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _caseTypeLabel(String type) => switch (type) {
    'tree_cutting_inspection' => 'Tree cutting inspection',
    _ => 'Environmental report',
  };

  void _showDetails(
    BuildContext context,
    Map<String, dynamic> record,
    String caseId,
  ) {
    final photos = (record['photos'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final files = (record['files'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final seedlingsRequired =
        (record['seedlingsRequired'] as num?)?.toInt() ?? 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                (record['title'] ?? 'Inspection case').toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_caseTypeLabel((record['caseType'] ?? '').toString())} · '
                '${(record['status'] ?? 'draft').toString().toUpperCase()}',
                style: const TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 16),
              if ((record['caseType'] ?? '') == 'tree_cutting_inspection' &&
                  (record['status'] ?? '') == 'submitted' &&
                  seedlingsRequired > 0)
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SeedlingFollowUpScreen(
                          caseId: caseId,
                          caseTitle: (record['title'] ?? 'Tree inspection')
                              .toString(),
                          seedlingsRequired: seedlingsRequired,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.nature_outlined),
                  label: const Text('Seedling Follow-up'),
                ),
              if (record['visitScheduledAt'] != null)
                _DetailRow(
                  label: 'Next Visit',
                  value: _formatDate(_date(record['visitScheduledAt'])),
                ),
              _DetailRow(label: 'Findings', value: record['findings']),
              _DetailRow(label: 'Severity', value: record['severity']),
              _DetailRow(label: 'Urgency', value: record['urgency']),
              _DetailRow(label: 'Site address', value: record['siteAddress']),
              _DetailRow(label: 'Barangay', value: record['barangay']),
              _DetailRow(
                label: 'Officer Attestation',
                value: record['officerAttestation'],
              ),
              if (record['checklistResponses'] is Map) ...[
                const SizedBox(height: 8),
                const Text(
                  'Checklist',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...(record['checklistResponses'] as Map).entries.map(
                  (entry) => ListTile(
                    dense: true,
                    leading: Icon(
                      entry.value == true
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: entry.value == true
                          ? AppColors.primary
                          : AppColors.textGrey,
                    ),
                    title: Text(entry.key.toString()),
                  ),
                ),
              ],
              if (record['activityHistory'] is List) ...[
                const SizedBox(height: 8),
                const Text(
                  'Case History',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...(record['activityHistory'] as List).whereType<Map>().map(
                  (event) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.history,
                      color: AppColors.primary,
                    ),
                    title: Text((event['event'] ?? 'Updated').toString()),
                    subtitle: Text(
                      '${event['actorName'] ?? 'Officer'} · ${event['at'] ?? ''}',
                    ),
                  ),
                ),
              ],
              _DetailRow(
                label: 'Coordinates',
                value: record['latitude'] == null || record['longitude'] == null
                    ? null
                    : '${record['latitude']}, ${record['longitude']}',
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Photos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photos.map((photo) {
                    final url = (photo['url'] ?? '').toString();
                    final point = photo['annotationPoint'];
                    final markerX = point is Map
                        ? (point['x'] as num?)?.toDouble()
                        : null;
                    final markerY = point is Map
                        ? (point['y'] as num?)?.toDouble()
                        : null;
                    return SizedBox(
                      width: 96,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            height: 92,
                            child: LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const SizedBox(
                                        width: 92,
                                        height: 92,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (markerX != null && markerY != null)
                                    Positioned(
                                      left: markerX * constraints.maxWidth - 12,
                                      top: markerY * constraints.maxHeight - 20,
                                      child: const Icon(
                                        Icons.location_on,
                                        size: 22,
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            (photo['phase'] ?? '').toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          if ((photo['caption'] ?? '').toString().isNotEmpty)
                            SizedBox(
                              width: 92,
                              child: Text(
                                photo['caption'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          if (photo['measurementCm'] != null)
                            Text(
                              '${photo['measurementCm']} cm',
                              style: const TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (files.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Attached Files',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...files.map(
                  (file) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text((file['name'] ?? 'File').toString()),
                    subtitle: SelectableText((file['url'] ?? '').toString()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Object? value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'draft';
    final label = switch (status) {
      'draft' => 'Draft',
      'submitted' => 'Submitted',
      'forwarded_to_denr_officer' => 'For DENR Review',
      _ => status,
    };
    final color = isDraft ? Colors.orange.shade800 : AppColors.primary;
    return Chip(
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      backgroundColor: color.withValues(alpha: 0.08),
      labelStyle: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
