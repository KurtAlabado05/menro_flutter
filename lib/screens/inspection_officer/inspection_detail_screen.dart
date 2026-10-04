import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../models/inspection_application_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/photo_gallery_section.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import 'case_documentation_screen.dart';

/// Read-only application details + editable inspection findings, mirroring
/// the web admin's Inspection Officer modal.
class InspectionDetailScreen extends StatefulWidget {
  final InspectionApplicationModel application;

  const InspectionDetailScreen({super.key, required this.application});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  late InspectionFindings _findings;
  late final TextEditingController _locationController;
  late final TextEditingController _treesController;
  late final TextEditingController _scenarioController;
  DateTime? _inspectionDate;

  bool _mutating = false;
  String? _mutationError;

  bool get _findingsUnlocked => widget.application.status == 'approved_by_denr';

  @override
  void initState() {
    super.initState();
    _findings = widget.application.buildFindings();
    _locationController = TextEditingController(
      text: _findings.locationOfTrees,
    );
    _treesController = TextEditingController(text: _findings.numberOfTrees);
    _scenarioController = TextEditingController(text: _findings.scenarioReason);
    _inspectionDate = DateTime.tryParse(_findings.inspectionDate);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _treesController.dispose();
    _scenarioController.dispose();
    super.dispose();
  }

  InspectionFindings get _currentFindings => _findings.copyWith(
    inspectionDate: _inspectionDate == null
        ? ''
        : _inspectionDate!.toIso8601String().split('T').first,
    scenarioReason: _scenarioController.text,
    numberOfTrees: _treesController.text,
    locationOfTrees: _locationController.text,
  );

  Future<void> _pickInspectionDate() async {
    if (!_findingsUnlocked) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _inspectionDate = picked);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _mutating = true;
      _mutationError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _mutationError = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _handleSaveFindings() async {
    final actingUser = context.read<AuthProvider>().user;
    if (actingUser == null) return;
    final provider = context.read<InspectionProvider>();
    await _run(() async {
      await provider.saveFindings(
        application: widget.application,
        findings: _currentFindings,
        actingUser: actingUser,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          'Inspection findings saved',
          type: AppMessageType.success,
        );
      }
    });
  }

  Future<void> _handleConfirmAndSendEmail() async {
    final actingUser = context.read<AuthProvider>().user;
    if (actingUser == null) return;
    final provider = context.read<InspectionProvider>();
    await _run(() async {
      await provider.confirmInspectionAndSendEmail(
        application: widget.application,
        findings: _currentFindings,
        actingUser: actingUser,
      );
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _handleForwardToDenr() async {
    final findings = _currentFindings;
    final missingDate = findings.inspectionDate.isEmpty;
    final missingScenario = findings.scenarioReason.trim().isEmpty;

    if (missingDate || missingScenario) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Forward to DENR?'),
          content: const Text(
            'Inspection date and scenario can be filled after DENR approves. Forward to DENR now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Forward'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    final actingUser = context.read<AuthProvider>().user;
    if (actingUser == null) return;
    final provider = context.read<InspectionProvider>();
    await _run(() async {
      await provider.forwardToDenr(
        application: widget.application,
        findings: findings,
        actingUser: actingUser,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          'Forwarded to DENR Officer',
          type: AppMessageType.success,
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _handleResolve() async {
    final actingUser = context.read<AuthProvider>().user;
    if (actingUser == null) return;
    final provider = context.read<InspectionProvider>();
    await _run(() async {
      await provider.resolve(
        application: widget.application,
        actingUser: actingUser,
      );
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    if (application.sourceCollection == 'reports') {
      return _EnvironmentalReportDetailScreen(report: application);
    }
    final findings = _findings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          application.applicantName.isEmpty
              ? 'Application'
              : application.applicantName,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${application.applicantEmail.isEmpty ? "—" : application.applicantEmail} · '
                    '${application.applicationType.isEmpty ? application.type : application.applicationType}',
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  _DocumentsSection(documents: application.documents),
                  if (application.type == 'tree_cutting_permit') ...[
                    const SizedBox(height: 16),
                    _PermitDetailsSection(permitData: application.raw),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CaseDocumentationScreen(
                            linkedSource: application,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.post_add_outlined),
                      label: const Text('Create Case Documentation'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Application Details',
                    subtitle:
                        'Auto-filled from Firebase and locked for review.',
                    child: _DetailsGrid(findings: findings),
                  ),
                  const SizedBox(height: 16),
                  if (application.documents.isNotEmpty)
                    PhotoGallerySection(
                      documents: application.documents
                          .map(
                            (doc) => PhotoDocument(
                              url: doc.url,
                              name: doc.name,
                              kind: doc.name.toLowerCase().contains('tree')
                                  ? 'tree-picture'
                                  : 'document',
                              verified: doc.verified,
                            ),
                          )
                          .toList(),
                      title: 'Application Documents',
                      subtitle: 'Attached tree photos and supporting documents',
                    ),
                  if (application.documents.isNotEmpty)
                    const SizedBox(height: 16),
                  _StatusHistorySection(
                    entries: application.raw['statusHistory'] is List
                        ? application.raw['statusHistory'] as List
                        : const [],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Inspection Findings',
                    subtitle: _findingsUnlocked
                        ? 'Editable — DENR has approved this application.'
                        : 'Locked until approved by DENR.',
                    child: _FindingsForm(
                      enabled: _findingsUnlocked,
                      inspectionDate: _inspectionDate,
                      actionType: findings.actionType,
                      locationController: _locationController,
                      treesController: _treesController,
                      scenarioController: _scenarioController,
                      onPickDate: _pickInspectionDate,
                      onActionTypeChanged: (value) {
                        setState(
                          () =>
                              _findings = _findings.copyWith(actionType: value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Seedlings required: ${_currentFindings.seedlingsRequired} '
                      '(${findings.actionType == "cutting" ? "1 tree = 3 seedlings" : "trimming = no seedlings"})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                  if (_mutationError != null) ...[
                    const SizedBox(height: 12),
                    ErrorState(
                      title: 'Failed to save findings',
                      subtitle: _mutationError,
                      onRetry: () => setState(() => _mutationError = null),
                      retryLabel: 'Dismiss',
                    ),
                  ],
                ],
              ),
            ),
            _ActionBar(
              mutating: _mutating,
              isApprovedByDenr:
                  application.status.trim().toLowerCase() == 'approved_by_denr',
              onSaveFindings: _findingsUnlocked ? _handleSaveFindings : null,
              onConfirmAndSendEmail: _handleConfirmAndSendEmail,
              onForwardToDenr: _handleForwardToDenr,
              onResolve: _handleResolve,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentalReportDetailScreen extends StatelessWidget {
  final InspectionApplicationModel report;

  const _EnvironmentalReportDetailScreen({required this.report});

  @override
  Widget build(BuildContext context) {
    final submittedAt = report.submittedAt?.toLocal().toString();
    final history = report.raw['statusHistory'] is List
        ? report.raw['statusHistory'] as List
        : const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Environmental Report'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.raw['title']?.toString().trim().isNotEmpty == true
                      ? report.raw['title'].toString()
                      : report.category.isEmpty
                      ? 'Environmental Report'
                      : report.category,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Report Details',
            subtitle: report.category.isEmpty
                ? 'Community-submitted report'
                : report.category,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReportDetailRow(
                  label: 'Description',
                  value: report.description,
                ),
                _ReportDetailRow(
                  label: 'Location',
                  value: report.applicationAddress,
                ),
                _ReportDetailRow(
                  label: 'Barangay',
                  value: report.raw['barangay'],
                ),
                _ReportDetailRow(
                  label: 'Landmark',
                  value: report.raw['landmark'] ?? report.raw['sitio'],
                ),
                _ReportDetailRow(
                  label: 'Submitted by',
                  value: report.applicantName,
                ),
                _ReportDetailRow(
                  label: 'Contact',
                  value: report.raw['submittedByContact'],
                ),
                _ReportDetailRow(label: 'Submitted', value: submittedAt),
                _ReportDetailRow(
                  label: 'Coordinates',
                  value:
                      report.raw['latitude'] == null ||
                          report.raw['longitude'] == null
                      ? null
                      : '${report.raw['latitude']}, ${report.raw['longitude']}',
                ),
              ],
            ),
          ),
          if (report.documents.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Evidence',
              subtitle: '${report.documents.length} attached image(s)',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: report.documents
                    .map(
                      (document) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          document.url,
                          width: 128,
                          height: 128,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 128,
                            height: 128,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _StatusHistorySection(entries: history),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CaseDocumentationScreen(linkedSource: report),
            ),
          ),
          icon: const Icon(Icons.post_add_outlined),
          label: const Text('Create Case Documentation'),
        ),
      ),
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  final String label;
  final Object? value;

  const _ReportDetailRow({required this.label, required this.value});

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

class _StatusHistorySection extends StatelessWidget {
  final List entries;

  const _StatusHistorySection({required this.entries});

  @override
  Widget build(BuildContext context) {
    final history = entries.whereType<Map>().toList().reversed.toList();
    return _SectionCard(
      title: 'Application History',
      subtitle: 'Recorded status changes and staff actions.',
      child: history.isEmpty
          ? const Text(
              'No status history recorded.',
              style: TextStyle(color: AppColors.textGrey),
            )
          : Column(
              children: history.map((entry) {
                final updatedBy = entry['updatedBy'];
                final actor = updatedBy is Map
                    ? (updatedBy['name'] ?? updatedBy['role'] ?? 'Staff')
                          .toString()
                    : 'Staff';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.history, color: AppColors.primary),
                  title: Text(
                    (entry['message'] ?? entry['status'] ?? 'Status updated')
                        .toString(),
                  ),
                  subtitle: Text(
                    '$actor · ${_historyDate(entry['timestamp'] ?? entry['updatedAt'])}',
                  ),
                );
              }).toList(),
            ),
    );
  }

  static String _historyDate(Object? value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    date ??= DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Time unavailable';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  final InspectionFindings findings;

  const _DetailsGrid({required this.findings});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Applicant', findings.applicantName),
      ('Email', findings.email),
      ('Contact Number', findings.contactNumber),
      ('Address', findings.address),
      ('Application Type', findings.applicationType),
      ('Kind of Tree', findings.kindOfTree),
      ('Tree Location', findings.locationOfTrees),
      ('Number of Trees', findings.numberOfTrees),
      ('Reason for Request', findings.reasonForRequest),
      ('PTA Requirement Basis', findings.ptaRequirementBasis),
      (
        'Legal Certification',
        findings.legalCertificationChecked ? 'Checked' : 'Unchecked',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: rows.map((row) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 32 - 44) / 2,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.$2.isEmpty ? '—' : row.$2,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FindingsForm extends StatelessWidget {
  final bool enabled;
  final DateTime? inspectionDate;
  final String actionType;
  final TextEditingController locationController;
  final TextEditingController treesController;
  final TextEditingController scenarioController;
  final VoidCallback onPickDate;
  final ValueChanged<String> onActionTypeChanged;

  const _FindingsForm({
    required this.enabled,
    required this.inspectionDate,
    required this.actionType,
    required this.locationController,
    required this.treesController,
    required this.scenarioController,
    required this.onPickDate,
    required this.onActionTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: enabled ? onPickDate : null,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Inspection Date',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: Text(
              inspectionDate == null
                  ? 'Select date'
                  : '${inspectionDate!.year}-${inspectionDate!.month.toString().padLeft(2, '0')}-${inspectionDate!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: actionType,
          decoration: const InputDecoration(
            labelText: 'Action Type',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'cutting', child: Text('Cutting')),
            DropdownMenuItem(value: 'trimming', child: Text('Trimming')),
          ],
          onChanged: enabled
              ? (value) => onActionTypeChanged(value ?? 'cutting')
              : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: treesController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of Trees',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: locationController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Location of Tree(s)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: scenarioController,
          enabled: enabled,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Scenario / Reason',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final List<InspectionDocument> documents;

  const _DocumentsSection({required this.documents});

  void _openPreview(BuildContext context, InspectionDocument doc) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: Image.network(
                    doc.url,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Preview unavailable for this file type.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Documents',
      subtitle: 'Verified is managed by Receiving Clerk.',
      child: documents.isEmpty
          ? const Text(
              'No documents submitted.',
              style: TextStyle(color: AppColors.textGrey),
            )
          : Column(
              children: documents.map((doc) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    doc.verified ? Icons.check_circle : Icons.hourglass_empty,
                    color: doc.verified
                        ? AppColors.primary
                        : AppColors.textGrey,
                  ),
                  title: Text(doc.name),
                  trailing: const Icon(Icons.visibility_outlined),
                  onTap: () => _openPreview(context, doc),
                );
              }).toList(),
            ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool mutating;
  final bool isApprovedByDenr;
  final VoidCallback? onSaveFindings;
  final VoidCallback onConfirmAndSendEmail;
  final VoidCallback onForwardToDenr;
  final VoidCallback onResolve;

  const _ActionBar({
    required this.mutating,
    required this.isApprovedByDenr,
    required this.onSaveFindings,
    required this.onConfirmAndSendEmail,
    required this.onForwardToDenr,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: mutating ? null : onSaveFindings,
                child: const Text('Save Findings'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: mutating ? null : onConfirmAndSendEmail,
                child: const Text('Confirm & Email'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprovedByDenr
                      ? AppColors.primary
                      : AppColors.statusForwardedToDENR,
                  foregroundColor: Colors.white,
                ),
                onPressed: mutating
                    ? null
                    : (isApprovedByDenr ? onResolve : onForwardToDenr),
                child: Text(isApprovedByDenr ? 'Resolve' : 'Forward to DENR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermitDetailsSection extends StatelessWidget {
  final Map<String, dynamic> permitData;

  const _PermitDetailsSection({required this.permitData});

  @override
  Widget build(BuildContext context) {
    final species = permitData['species'] ?? '';
    final numberOfTrees = permitData['numberOfTrees'] ?? 0;
    final reasonForCutting = permitData['reasonForCutting'] ?? '';
    final locationCategory = permitData['locationCategory'] ?? '';
    final treePictures = List<String>.from(
      permitData['treePicturesPaths'] ?? [],
    );
    final speciesId =
        permitData['speciesIdentification'] as Map<String, dynamic>?;

    return _SectionCard(
      title: 'Permit Details',
      subtitle: 'Tree cutting application information.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Tree Species', value: species),
          _DetailRow(label: 'Number of Trees', value: numberOfTrees.toString()),
          _DetailRow(label: 'Reason for Cutting', value: reasonForCutting),
          _DetailRow(label: 'Location Category', value: locationCategory),
          if (permitData['speciesVerification'] == 'unverified_onsite') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Species unverified: '
                      '${(permitData['unverifiedTreePhotoUrls'] as List?)?.length ?? 0} '
                      'tree photo(s) could not be identified (e.g. leafless or dead tree) '
                      'and were accepted as on-site photos near the pinned location. '
                      'Confirm the species during inspection.',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (speciesId != null && speciesId.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Species Identification',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            if (speciesId['photoPath'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  speciesId['photoPath'] as String,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
          ],
          if (treePictures.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Tree Photos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: treePictures.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    treePictures[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
