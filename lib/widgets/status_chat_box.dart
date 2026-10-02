import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/status_config.dart';
import '../models/report_model.dart';
import '../services/cloudinary_image_service.dart';

class StatusChatBox extends StatefulWidget {
  final String collectionName;
  final String documentId;
  final String? ownerUid;
  final String status;
  final List<ReportStatusUpdate> statusHistory;
  final String? latestStatusMessage;
  final String title;

  const StatusChatBox({
    super.key,
    required this.collectionName,
    required this.documentId,
    this.ownerUid,
    required this.status,
    this.statusHistory = const [],
    this.latestStatusMessage,
    this.title = 'Conversation',
  });

  @override
  State<StatusChatBox> createState() => _StatusChatBoxState();
}

class _StatusChatBoxState extends State<StatusChatBox> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _cloudinary = const CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );
  bool _isSending = false;
  bool _canReply = false;
  bool _isCaseOwner = false;
  bool _permissionLoaded = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String _selectedTopic = 'Question about this case';

  static const _reporterTopics = [
    'Question about this case',
    'Provide additional information',
    'Respond to a staff request',
  ];

  CollectionReference<Map<String, dynamic>> get _messages => _db
      .collection(widget.collectionName)
      .doc(widget.documentId)
      .collection('messages');

  @override
  void initState() {
    super.initState();
    _loadReplyPermission();
  }

  Future<void> _loadReplyPermission() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _permissionLoaded = true);
      return;
    }

    final isCaseOwner = widget.ownerUid == user.uid;
    var isStaff = false;
    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role']?.toString().toLowerCase().trim();
      isStaff = {
        'admin',
        'staff',
        'menro',
        'denr',
        'menro_staff',
        'denr_staff',
      }.contains(role);
    } catch (error) {
      debugPrint('Could not resolve chat permissions: $error');
    }

    if (mounted) {
      setState(() {
        _isCaseOwner = isCaseOwner;
        _canReply = isCaseOwner || isStaff;
        _permissionLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final user = _auth.currentUser;
    if ((message.isEmpty && _selectedImageBytes == null) ||
        user == null ||
        _isSending ||
        message.length > 1000) {
      return;
    }

    setState(() => _isSending = true);
    try {
      String? imageUrl;
      if (_selectedImageBytes != null && _selectedImageName != null) {
        imageUrl = await _cloudinary.uploadImage(
          bytes: _selectedImageBytes!,
          fileName:
              'case_${DateTime.now().millisecondsSinceEpoch}_$_selectedImageName',
        );
      }
      await _messages.add({
        'message': message,
        'imageUrl': imageUrl,
        'authorUid': user.uid,
        'authorRole': _isCaseOwner ? 'reporter' : 'staff',
        'messageType': _isCaseOwner ? 'reporter_message' : 'staff_reply',
        if (_isCaseOwner) 'topic': _selectedTopic,
        'authorName': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email ?? 'User',
        'sentAt': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachments must be 5 MB or smaller.')),
        );
      }
      return;
    }
    setState(() {
      _selectedImageBytes = file.bytes;
      _selectedImageName = file.name;
    });
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Sending...';
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} · $hour:$minute $period';
  }

  Widget _buildActivity(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) {
    final activities =
        <_CaseActivity>[
          ...widget.statusHistory.map(_CaseActivity.status),
          ...messages.map((doc) {
            final data = doc.data();
            final sentAt = data['sentAt'];
            return _CaseActivity.message(
              data,
              sentAt is Timestamp ? sentAt.toDate() : null,
            );
          }),
        ]..sort((first, second) {
          if (first.timestamp == null) return second.timestamp == null ? 0 : 1;
          if (second.timestamp == null) return -1;
          return first.timestamp!.compareTo(second.timestamp!);
        });

    if (activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No case activity has been recorded yet.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: ListView.separated(
        padding: const EdgeInsets.only(right: 4),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final activity = activities[index];
          if (activity.statusUpdate != null) {
            final update = activity.statusUpdate!;
            final config = StatusConfig.fromStatus(update.status);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.08),
                border: Border.all(color: config.color.withValues(alpha: 0.24)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(config.icon, size: 18, color: config.color),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Official status update',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        config.label,
                        style: TextStyle(
                          color: config.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (update.message.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(update.message),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (update.updatedBy?.trim().isNotEmpty == true)
                        update.updatedBy!,
                      _formatDateTime(update.timestamp),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = activity.messageData!;
          final isReporter =
              data['authorUid'] == widget.ownerUid ||
              data['authorRole'] == 'reporter';
          final author = data['authorName']?.toString().trim();
          final imageUrl = data['imageUrl']?.toString() ?? '';
          final message = data['message']?.toString() ?? '';
          final topic = data['topic']?.toString().trim() ?? '';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isReporter ? Icons.person_outline : Icons.support_agent,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        author?.isNotEmpty == true
                            ? author!
                            : isReporter
                            ? 'Case submitter'
                            : 'MENRO staff',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      isReporter ? 'SUBMITTER UPDATE' : 'STAFF RESPONSE',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (topic.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    topic,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ],
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(message, style: const TextStyle(height: 1.4)),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatDateTime(activity.timestamp),
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = StatusConfig.fromStatus(widget.status);
    final user = _auth.currentUser;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusConfig.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusConfig.label,
                  style: TextStyle(
                    color: statusConfig.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Messages should relate to this case and its processing.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          if (widget.statusHistory.isEmpty &&
              widget.latestStatusMessage?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              widget.latestStatusMessage!,
              style: const TextStyle(color: AppColors.textGrey, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          if (!_permissionLoaded)
            const LinearProgressIndicator()
          else if (_canReply)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages
                  .orderBy('sentAt', descending: false)
                  .limitToLast(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Case correspondence is unavailable right now.',
                    style: TextStyle(color: Colors.redAccent),
                  );
                }
                return _buildActivity(snapshot.data?.docs ?? const []);
              },
            )
          else ...[
            _buildActivity(const []),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Correspondence is visible only to the report owner and authorized staff.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ),
          ],
          if (_canReply) ...[
            const Divider(height: 24),
            if (_isCaseOwner) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedTopic,
                decoration: const InputDecoration(
                  labelText: 'Reason for contacting the office',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _reporterTopics
                    .map(
                      (topic) =>
                          DropdownMenuItem(value: topic, child: Text(topic)),
                    )
                    .toList(),
                onChanged: _isSending
                    ? null
                    : (topic) {
                        if (topic != null) {
                          setState(() => _selectedTopic = topic);
                        }
                      },
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _messageController,
              enabled: user != null && !_isSending,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _isCaseOwner
                    ? 'Add information relevant to this case...'
                    : 'Write an official case response...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: user == null || _isSending ? null : _pickImage,
                  tooltip: 'Attach case evidence (5 MB maximum)',
                  icon: const Icon(Icons.attach_file),
                ),
                if (_selectedImageBytes != null)
                  Expanded(
                    child: Text(
                      _selectedImageName ?? 'Image attached',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                FilledButton.icon(
                  onPressed: user == null || _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_isCaseOwner ? 'Send update' : 'Send response'),
                ),
              ],
            ),
            if (_selectedImageBytes != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isSending
                      ? null
                      : () => setState(() {
                          _selectedImageBytes = null;
                          _selectedImageName = null;
                        }),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove attachment'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CaseActivity {
  final DateTime? timestamp;
  final ReportStatusUpdate? statusUpdate;
  final Map<String, dynamic>? messageData;

  const _CaseActivity._({
    required this.timestamp,
    this.statusUpdate,
    this.messageData,
  });

  factory _CaseActivity.status(ReportStatusUpdate update) =>
      _CaseActivity._(timestamp: update.timestamp, statusUpdate: update);

  factory _CaseActivity.message(
    Map<String, dynamic> data,
    DateTime? timestamp,
  ) => _CaseActivity._(timestamp: timestamp, messageData: data);
}
