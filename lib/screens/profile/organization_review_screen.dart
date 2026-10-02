import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/organization_registration_service.dart';

class OrganizationReviewScreen extends StatefulWidget {
  const OrganizationReviewScreen({super.key});

  @override
  State<OrganizationReviewScreen> createState() =>
      _OrganizationReviewScreenState();
}

class _OrganizationReviewScreenState extends State<OrganizationReviewScreen> {
  final _service = const OrganizationRegistrationService();
  late Future<Map<String, dynamic>> _queue;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _queue = _service.listPendingApplications();
  }

  void _refresh() {
    setState(() => _queue = _service.listPendingApplications());
  }

  Future<void> _review({
    required String organizationId,
    required String decision,
    String? representativeUid,
    required String processingKey,
  }) async {
    setState(() => _processing.add(processingKey));
    try {
      await _service.reviewApplication(
        organizationId: organizationId,
        decision: decision,
        representativeUid: representativeUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'verified' ? 'Review approved.' : 'Request rejected.',
          ),
        ),
      );
      _refresh();
    } on OrganizationFunctionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete the review.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(processingKey));
    }
  }

  Future<void> _rejectLookupRequest(String requestId) async {
    setState(() => _processing.add(requestId));
    try {
      await _service.rejectLookupRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Representative request rejected.')),
      );
      _refresh();
    } on OrganizationFunctionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to reject the request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Review'),
        actions: [
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is OrganizationFunctionException
                      ? (snapshot.error as OrganizationFunctionException)
                            .message
                      : 'Unable to load organization review items.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final result = snapshot.data ?? const <String, dynamic>{};
          final applications = _mapList(result['applications']);
          final representatives = _mapList(result['representativeRequests']);
          final unmatched = _mapList(result['unmatchedRequests']);
          if (applications.isEmpty &&
              representatives.isEmpty &&
              unmatched.isEmpty) {
            return const Center(
              child: Text('No organization requests to review.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (applications.isNotEmpty) ...[
                const _SectionHeading('Organization applications'),
                for (final application in applications)
                  _organizationCard(application),
              ],
              if (representatives.isNotEmpty) ...[
                const _SectionHeading('Representative requests'),
                for (final request in representatives)
                  _representativeCard(request),
              ],
              if (unmatched.isNotEmpty) ...[
                const _SectionHeading('Unmatched permit requests'),
                for (final request in unmatched) _unmatchedCard(request),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _mapList(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  Widget _organizationCard(Map<String, dynamic> item) {
    final id = item['organizationId'].toString();
    return _ReviewCard(
      title: item['legalName']?.toString() ?? 'Organization',
      details: [
        'Permit: ${item['permitIssuer']} ${item['permitNumber']}',
        'Jurisdiction: ${item['jurisdiction']}',
        if ((item['reviewFlags'] as List?)?.contains(
              'possible_name_duplicate',
            ) ??
            false)
          'Check for an existing organization with a similar name.',
        if ((item['permitDocumentUrl']?.toString() ?? '').isNotEmpty)
          'Document: ${item['permitDocumentUrl']}',
      ],
      busy: _processing.contains(id),
      onApprove: () =>
          _review(organizationId: id, decision: 'verified', processingKey: id),
      onReject: () =>
          _review(organizationId: id, decision: 'rejected', processingKey: id),
    );
  }

  Widget _representativeCard(Map<String, dynamic> item) {
    final organizationId = item['organizationId'].toString();
    final representativeUid = item['representativeUid'].toString();
    final key = '$organizationId:$representativeUid';
    return _ReviewCard(
      title: item['organizationName']?.toString() ?? 'Organization',
      details: [
        'Representative: ${item['representativeName']}',
        'Email: ${item['email']}',
      ],
      busy: _processing.contains(key),
      onApprove: () => _review(
        organizationId: organizationId,
        representativeUid: representativeUid,
        decision: 'verified',
        processingKey: key,
      ),
      onReject: () => _review(
        organizationId: organizationId,
        representativeUid: representativeUid,
        decision: 'rejected',
        processingKey: key,
      ),
    );
  }

  Widget _unmatchedCard(Map<String, dynamic> item) => _ReviewCard(
    title: item['legalName']?.toString() ?? 'Organization lookup request',
    details: [
      'No exact permit claim matched. Verify the permit before creating or linking an organization.',
      'Permit: ${item['permitIssuer']} ${item['permitNumber']}',
      'Jurisdiction: ${item['jurisdiction']}',
      'Requester: ${item['email']}',
    ],
    busy: _processing.contains(item['requestId']),
    onReject: () => _rejectLookupRequest(item['requestId'].toString()),
  );
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<String> details;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ReviewCard({
    required this.title,
    required this.details,
    this.busy = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final detail in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(detail),
            ),
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Reject request',
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
                IconButton(
                  tooltip: 'Approve request',
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
