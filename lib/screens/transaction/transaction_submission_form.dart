import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../models/charter_service_model.dart';
import '../../core/constants/app_colors.dart';

class TransactionSubmissionForm extends StatefulWidget {
  final CharterService? initialService;

  const TransactionSubmissionForm({super.key, this.initialService});


  @override
  State<TransactionSubmissionForm> createState() => _TransactionSubmissionFormState();
}

class _TransactionSubmissionFormState extends State<TransactionSubmissionForm> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  String? _error;

  List<CharterService> _services = const [];
  CharterService? _selectedService;

  // Structural local state map: requirement text -> storage URL
  final Map<String, String> uploadedFileUrls = <String, String>{};

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _officialReceiptController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // If hub passed an initial service, select it immediately so checklist slots render.
    if (widget.initialService != null) {
      _selectedService = widget.initialService;
      for (final req in widget.initialService!.requiredDocumentsList) {
        uploadedFileUrls.putIfAbsent(req, () => '');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCharterServices();
    });
  }

  @override
  void dispose() {
    _officialReceiptController.dispose();
    super.dispose();
  }

  Future<void> _loadCharterServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _db.collection('charter_matrix').get();
      final services = snapshot.docs.map((doc) {
        final data = doc.data();
        // Ensure documentId is used as serviceCode fallback
        return CharterService.fromFirestore(data, documentId: doc.id);
      }).toList();

      setState(() {
        _services = services;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load service charter rules. ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onServiceSelected(CharterService? service) {
    setState(() {
      _selectedService = service;
      uploadedFileUrls.clear();
      // Pre-create keys (optional, but keeps completeness logic straightforward)
      if (service != null) {
        for (final req in service.requiredDocumentsList) {
          uploadedFileUrls.putIfAbsent(req, () => '');
        }
      }
    });
  }

  // Completeness: exactly all required docs have non-empty valid upload strings.
  bool get _isReadyToSubmit {
    final service = _selectedService;
    if (service == null) return false;

    final required = service.requiredDocumentsList;
    // Only unlock when uploadedFileUrls includes every required and each has a non-empty URL.
    if (uploadedFileUrls.length != required.length) return false;

    for (final req in required) {
      final url = uploadedFileUrls[req];
      if (url == null || url.trim().isEmpty) return false;
    }

    return true;
  }

  String _workflowTierDefault() {
    return 'ReceivingClerk';
  }

  Future<String?> _uploadPlaceholderForRequirement(String requirementText) async {
    // NOTE: UI contract asked for dynamic file pick/upload widgets.
    // This repo currently has no Storage upload picker wired for arbitrary documents.
    // To keep the form functional while enforcing schema, this method expects
    // a Storage URL to be supplied via UI.
    //
    // For now, we show a dialog asking user to paste a Firebase Storage URL.

    final urlController = TextEditingController();

    final completer = Completer<String?>();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Upload Document'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'Paste Firebase Storage URL (e.g., https://.../file.pdf)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                completer.complete(null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Storage URL cannot be empty.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                completer.complete(url);
              },
              child: const Text('Set Upload'),
            ),
          ],
        );
      },
    );

    return completer.future;
  }

  Future<void> _handleUploadForRequirement(String requirementText) async {
    final url = await _uploadPlaceholderForRequirement(requirementText);
    if (url == null) return;

    setState(() {
      uploadedFileUrls[requirementText] = url;
    });
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final service = _selectedService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service first.')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to submit.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Find applicant display name from users doc if available.
      String applicantName = 'Unknown';
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        final data = userDoc.data();
        if (data != null && data['name'] is String) {
          applicantName = data['name'] as String;
        }
      } catch (_) {
        // Non-fatal: keep default name
      }

      final now = Timestamp.now();
      final targetCompletion = DateTime.now().add(
        Duration(hours: service.mandatedSlaHours),
      );

      // transactionNumber format requested by schema.
      // If you have a generator elsewhere, we can wire it later.
      final transactionNumber = 'TXN-2026-MENROB-${DateTime.now().millisecondsSinceEpoch}';

      // Build dynamicChecklistAttachments exactly as required by schema.
      final dynamicChecklistAttachments = <Map<String, dynamic>>[];
      for (final req in service.requiredDocumentsList) {
        final fileUrl = uploadedFileUrls[req];
        if (fileUrl == null || fileUrl.trim().isEmpty) {
          throw StateError('Missing upload for requirement: $req');
        }
        dynamicChecklistAttachments.add({
          'requirementName': req,
          'fileUrl': fileUrl,
          'isVerified': false,
        });
      }

      // Minimal routing history entry.
      final routingHistory = <Map<String, dynamic>>[
        {
          'tier': _workflowTierDefault(),
          'actorUid': user.uid,
          'action': 'SUBMITTED',
          'notes': 'Citizen submitted initial application with checklist attachments.',
          'timestamp': now,
        },
      ];

      final feesRequired = service.legalFees;

      // Create doc with auto-id.
      final docRef = _db.collection('services_transactions').doc();

      final txnPayload = <String, dynamic>{
        'transactionNumber': transactionNumber,
        'charterServiceCode': service.serviceCode,
        'serviceName': service.serviceName,
        'applicantUid': user.uid,
        'applicantName': applicantName,
        'submittedAt': now,
        'targetSlaCompletionDate': Timestamp.fromDate(targetCompletion),
        'isSlaBreached': false,
        'feesRequired': feesRequired,
        'officialReceiptNumber': _officialReceiptController.text.trim(),
        'currentWorkflowTier': _workflowTierDefault(),
        'status': 'Pending Verification',
        'dynamicChecklistAttachments': dynamicChecklistAttachments,
        'routingHistory': routingHistory,

        // Severity is determined ONLY by admin on backend dashboard.
        // Citizens must not determine/compute it.
        'severity': null,
        'severityStatus': 'Pending Admin Assessment',
        'severityDeterminedBy': null,
        'severityDeterminedAt': null,
      };

      // Use try/catch and bubble descriptive message.
      await docRef.set(txnPayload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submitted successfully. Ref: $transactionNumber'),
            backgroundColor: AppColors.primary,
          ),
        );
      }

      if (mounted) {
        setState(() {
          // reset
          _selectedService = null;
          uploadedFileUrls.clear();
          _officialReceiptController.clear();
          _error = null;
        });
      }
    } catch (e) {
      final msg = 'Submission failed. Please check your inputs and try again. ${e.toString()}';
      setState(() {
        _error = msg;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildServiceDropdown() {
    return DropdownButtonFormField<CharterService>(
      value: _selectedService,
      decoration: InputDecoration(
        labelText: 'Select Service',
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      isExpanded: true,
      items: _services
          .map(
            (s) => DropdownMenuItem<CharterService>(
              value: s,
              child: Text(
                '${s.serviceCode} • ${s.serviceName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (val) => _onServiceSelected(val),
    );
  }

  Widget _buildCharterInfoCard() {
    final service = _selectedService;
    if (service == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.serviceName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _infoRow(
                  icon: Icons.timer_outlined,
                  title: 'Guaranteed Processing Time',
                  value: '${((service.mandatedSlaHours / 8).ceil())} Working Day${((service.mandatedSlaHours / 8).ceil()) > 1 ? 's' : ''}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Processing Fee',
                  value: service.legalFees <= 0 ? 'Free of Charge' : '₱${service.legalFees.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Required Documents: ${service.requiredDocumentsList.length}',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistUploads() {
    final service = _selectedService;
    if (service == null) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic Document Checklist',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: service.requiredDocumentsList.length,
              itemBuilder: (context, index) {
                final requirement = service.requiredDocumentsList[index];
                final url = uploadedFileUrls[requirement] ?? '';
                final isUploaded = url.trim().isNotEmpty;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isUploaded ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                    child: Icon(
                      isUploaded ? Icons.check_circle_outline : Icons.upload_outlined,
                      color: isUploaded ? Colors.green : AppColors.textGrey,
                    ),
                  ),
                  title: Text(
                    requirement,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: isUploaded
                      ? const Text('Uploaded')
                      : const Text('Not uploaded yet'),
                  trailing: OutlinedButton.icon(
                    onPressed: () => _handleUploadForRequirement(requirement),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(isUploaded ? 'Change' : 'Upload'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit MENRO Baliwag Service Request'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (_isLoading)
                    const LinearProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 12),
                  _buildServiceDropdown(),
                  const SizedBox(height: 16),
                  _buildCharterInfoCard(),
                  const SizedBox(height: 16),
                  _buildChecklistUploads(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _officialReceiptController,
                    decoration: const InputDecoration(
                      labelText: 'Official Receipt Number (optional)',
                      hintText: 'e.g., OR-123456',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedService != null && _isReadyToSubmit && !_isLoading)
                          ? _submit
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isReadyToSubmit ? 'Submit Application' : 'Upload all required documents to submit',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Submit unlocks only when every required document has an upload URL assigned.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

