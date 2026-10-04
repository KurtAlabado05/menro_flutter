import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/status_config.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/status_chat_box.dart';

class TreeCuttingPermitDetailsScreen extends StatefulWidget {
  final String permitId;

  const TreeCuttingPermitDetailsScreen({super.key, required this.permitId});

  @override
  State<TreeCuttingPermitDetailsScreen> createState() =>
      _TreeCuttingPermitDetailsScreenState();
}

class _TreeCuttingPermitDetailsScreenState
    extends State<TreeCuttingPermitDetailsScreen> {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> _loadPermit() async {
    final doc = await _db
        .collection('tree_cutting_permits')
        .doc(widget.permitId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  DateTime? _safeTimestampToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _safeString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value.trim();
    if (value is Map) {
      for (final key in ['url', 'secure_url', 'downloadUrl', 'value', 'name', 'label']) {
        final nested = value[key];
        if (nested is String && nested.trim().isNotEmpty) return nested.trim();
      }
    }
    return value.toString().trim();
  }

  String? _safeNullableString(dynamic value) {
    final parsed = _safeString(value);
    return parsed.isEmpty ? null : parsed;
  }

  List<String> _safeStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map(_safeString).where((item) => item.isNotEmpty).toList();
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _shareApplication(String applicant, String trackingNo) {
    final text =
        'Tree Cutting Application Tracking No: $trackingNo submitted by $applicant';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application info copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Permit Details'),
        leading: const BackButton(),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadPermit(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Failed to load permit',
              subtitle: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final permit = snapshot.data;
          if (permit == null) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Permit Not Found',
              subtitle: 'No tree cutting permit exists for this ID.',
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }

          // Fields mapping extraction safely
          final kindOfTree = _safeString(
            permit['kindOfTree'],
            'Tree Cutting Application',
          );
          final numberOfTrees = permit['numberOfTrees'] ?? 0;
          final status = _safeString(permit['status'], 'pending');
          final trackingNo = _safeString(permit['trackingNo'], 'N/A');
          final submittedAt =
              _safeTimestampToDate(permit['submittedAt']) ?? DateTime.now();

          final applicantName = _safeString(
            permit['applicantName'],
            'Unknown Applicant',
          );
          final email = _safeString(permit['email'], '—');
          final contactNumber = _safeString(permit['contactNumber'], '—');
          final address = _safeString(permit['address'], '—');

          // File attachments map path mapping
          final uploadedPaths = permit['uploadedPaths'];
          final paths = uploadedPaths is Map ? uploadedPaths : null;

            final requestLetterUrl =
              _safeNullableString(paths?['letterOfRequestPath']);
            final lguBarangayCertificationUrl =
              _safeNullableString(paths?['barangayClearancePath']);
            final landTitleUrl = _safeNullableString(paths?['landTitlePath']);
            final ptaPresidentCertificationUrl =
              _safeNullableString(paths?['ptaPresidentCertificationPath']);

            final treePicturesUrls = _safeStringList(paths?['treePicturesPaths']);

          final speciesIdentification = permit['speciesIdentification'];
          final speciesIdMap =
              speciesIdentification is Map ? speciesIdentification : null;
            final aiScientificName =
              _safeNullableString(speciesIdMap?['suggestedScientificName']);
            final aiCommonNames =
              _safeStringList(speciesIdMap?['suggestedCommonNames']);
          final aiConfidence = (speciesIdMap?['confidence'] as num?)?.toDouble();
            final aiEvidenceUrls =
              _safeStringList(speciesIdMap?['evidencePhotoUrls']);

          // Status timeline structure array extraction from firestore safely
            final rawHistory = permit['statusHistory'] is List
              ? permit['statusHistory'] as List
              : const [];
          final statusHistory = rawHistory.map((item) {
            // 1. Safely handle the map conversion to prevent subtype casting crashes
            final map = item is Map ? item : {};
            
            return {
              'status': _safeString(map['status'], 'pending'),
              'message': _safeString(map['message']),
              // 2. Fallback check for both 'timestamp' and 'updatedAt' keys
              'timestamp': _safeTimestampToDate(map['timestamp'] ?? map['updatedAt']) ?? DateTime.now(),
              'updatedBy': _safeNullableString(map['updatedBy']),
            };
          }).toList();
            final latestStatusMessage = statusHistory.isEmpty
              ? null
              : statusHistory.last['message']?.toString();

          return RefreshIndicator(
            onRefresh: () => _loadPermit().then((_) => setState(() {})),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Primary Photo Anchor at the top
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: treePicturesUrls.isNotEmpty
                        ? Image.network(
                            treePicturesUrls.first,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 220,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                _buildImagePlaceholder(
                                  'Attachment Unavailable',
                                ),
                          )
                        : (landTitleUrl != null
                              ? Image.network(
                                  landTitleUrl,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : _buildImagePlaceholder('No Images Attached')),
                  ),
                  const SizedBox(height: 16),

                  // 2. Info Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: status, showIcon: true),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  _shareApplication(applicantName, trackingNo),
                              icon: const Icon(Icons.share_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          kindOfTree,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                applicantName,
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _timeAgo(submittedAt),
                              style: const TextStyle(color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Document Specifications Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.verified_outlined,
                          'Application Type',
                          _safeString(permit['applicationType'], '—'),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.park_outlined,
                          'Volume of Timber Assets',
                          '$numberOfTrees Trees Proposed',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.home_work_outlined,
                          'Registered Address',
                          address,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.contact_phone_outlined,
                          'Contact Number',
                          contactNumber,
                        ),
                      ],
                    ),
                  ),
                  if (speciesIdMap != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.biotech_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'AI Species Identification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            aiCommonNames.isNotEmpty
                                ? aiCommonNames.first
                                : (aiScientificName ?? 'Suggestion recorded'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (aiScientificName != null &&
                              aiScientificName.isNotEmpty)
                            Text(
                              aiScientificName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          if (aiConfidence != null)
                            Text(
                              'Confidence: ${(aiConfidence * 100).round()}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          const SizedBox(height: 6),
                          const Text(
                            'AI suggestion only. MENRO/DENR staff verify during inspection.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                          if (aiEvidenceUrls.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: aiEvidenceUrls.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    aiEvidenceUrls[index],
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 4. Enhanced Status Timeline Module Container
                  const Text(
                    'Status Timeline',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: statusHistory.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Application received. No progress history recorded yet.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              ...statusHistory.reversed
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final update = entry.value;
                                    return _buildTimelineTile(
                                      update,
                                      isLatest: index == 0,
                                      isLast: index == statusHistory.length - 1,
                                    );
                                  }),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  StatusChatBox(
                    collectionName: 'tree_cutting_permits',
                    documentId: widget.permitId,
                    ownerUid: _safeNullableString(permit['submittedByUid']),
                    status: status,
                    latestStatusMessage: latestStatusMessage,
                    title: 'Permit Conversation',
                  ),
                  const SizedBox(height: 24),

                  // 5. Attachments Grid Checklist Container
                  const Text(
                    'Submitted Attachments Checklist',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildAttachmentLinkTile(
                          title: 'Request Letter',
                          url: requestLetterUrl,
                          icon: Icons.insert_drive_file_outlined,
                        ),
                        const Divider(height: 16),
                        _buildAttachmentLinkTile(
                          title: 'LGU/Barangay Certification',
                          url: lguBarangayCertificationUrl,
                          icon: Icons.description_outlined,
                        ),
                        const Divider(height: 16),
                        _buildAttachmentLinkTile(
                          title: 'Land Title Documents',
                          url: landTitleUrl,
                          icon: Icons.assignment_outlined,
                        ),
                        const Divider(height: 16),
                        _buildAttachmentLinkTile(
                          title: 'PTA President Certification',
                          url: ptaPresidentCertificationUrl,
                          icon: Icons.verified_outlined,
                        ),
                        const Divider(height: 16),
                        _buildAttachmentLinkTile(
                          title:
                              'Photographs of Trees (${treePicturesUrls.length})',
                          url: treePicturesUrls.isNotEmpty
                              ? treePicturesUrls.first
                              : null,
                          icon: Icons.collections_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder(String text) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- Added Method implementation below to resolve structural layout breakages ---
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentLinkTile({
    required String title,
    required String? url,
    required IconData icon,
  }) {
    final hasUrl = url != null && url.trim().isNotEmpty;
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Icon(
          hasUrl ? Icons.check_circle : Icons.cancel_outlined,
          size: 20,
          color: hasUrl ? Colors.green : Colors.amber.shade700,
        ),
      ],
    );
  }

  Widget _buildTimelineTile(
    Map<String, dynamic> update, {
    required bool isLatest,
    required bool isLast,
  }) {
    final config = StatusConfig.fromStatus(_safeString(update['status'], 'pending'));
    final color = config.color;
    final timestamp = update['timestamp'] is DateTime
        ? update['timestamp'] as DateTime
        : DateTime.now();
    final updatedBy = _safeNullableString(update['updatedBy']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 3),
            Container(
              width: isLatest ? 16 : 12,
              height: isLatest ? 16 : 12,
              decoration: BoxDecoration(
                color: isLatest ? color : color.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: isLatest
                    ? Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 3.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                    : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isLatest ? color.withValues(alpha: 0.3) : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      config.label.toUpperCase(),
                      style: TextStyle(
                        fontWeight: isLatest
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isLatest ? color : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLatest ? Colors.grey[800] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  update['message'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: isLatest ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                if (updatedBy != null && updatedBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Processed by: $updatedBy',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
