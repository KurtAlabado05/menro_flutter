import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';
import '../providers/auth_provider.dart' as app_auth_provider;
import '../services/cloudinary_image_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/section_widgets.dart';
import '../widgets/tree_species_identify_sheet.dart';
import 'report/report_location_picker.dart';
import 'tree_cutting/tree_cutting_form_model.dart';
import 'tree_cutting/widgets/permit_applicant_step.dart';
import 'tree_cutting/widgets/permit_documents_step.dart';
import 'tree_cutting/widgets/permit_review_step.dart';
import 'tree_cutting/widgets/permit_step_header.dart';
import 'tree_cutting/widgets/permit_trees_step.dart';

enum _DocumentSource { camera, gallery, file }

class TreeCuttingApplicationScreen extends StatefulWidget {
  const TreeCuttingApplicationScreen({super.key});

  @override
  State<TreeCuttingApplicationScreen> createState() =>
      _TreeCuttingApplicationScreenState();
}

class _TreeCuttingApplicationScreenState
    extends State<TreeCuttingApplicationScreen> {
  static const List<String> _stepTitles = [
    'Applicant',
    'Trees & Location',
    'Documents',
    'Review & Submit',
  ];

  final TreeCuttingFormModel _model = TreeCuttingFormModel();
  final GlobalKey<FormState> _applicantKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _treesKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _reviewKey = GlobalKey<FormState>();
  final ScrollController _scroll = ScrollController();

  final CloudinaryImageService _cloudinary = const CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  int _step = 0;

  @override
  void initState() {
    super.initState();
    _model.prefillFrom(context.read<app_auth_provider.AuthProvider>().user);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _model.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _confirmExit() async {
    if (!_model.hasUserInput || _model.submitting) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard application?'),
        content: const Text(
          'Your answers and uploaded files will be lost if you leave now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _openSpeciesIdentify() async {
    final result = await TreeSpeciesIdentifySheet.show(
      context,
      cloudinary: _cloudinary,
    );
    if (!mounted || result == null) return;
    final suggestion = result.bestMatch;
    if (suggestion == null) return;

    _model.applySpeciesSuggestion(result);
    showAppSnackBar(
      context,
      'Species suggestion applied: ${suggestion.displayName}. You can still change it.',
    );
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportLocationPickerScreen(
          initialLat: _model.latitude,
          initialLng: _model.longitude,
        ),
      ),
    );
    if (result == null) return;
    _model.setLocation(result);
  }

  Future<_DocumentSource?> _askDocumentSource() {
    return showModalBottomSheet<_DocumentSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Upload Document',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SheetActionTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () => Navigator.pop(ctx, _DocumentSource.camera),
              ),
              SheetActionTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () => Navigator.pop(ctx, _DocumentSource.gallery),
              ),
              SheetActionTile(
                icon: Icons.attach_file_outlined,
                label: 'Browse Files (PDF, JPG, PNG)',
                onTap: () => Navigator.pop(ctx, _DocumentSource.file),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fileName(PermitAttachment kind, String? originalName) {
    final ext = (originalName != null && originalName.contains('.'))
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '';
    return 'tree_cutting_${kind.name}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  Future<String?> _pickAndUploadImage(
    PermitAttachment kind,
    ImageSource source,
  ) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    _model.setUploading(kind);
    final bytes = await picked.readAsBytes();
    return _cloudinary.uploadImage(
      bytes: bytes,
      fileName: _fileName(kind, picked.name),
    );
  }

  Future<String?> _pickAndUploadFile(PermitAttachment kind) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return null;
    _model.setUploading(kind);
    return _cloudinary.uploadRawFile(
      bytes: bytes,
      fileName: _fileName(kind, picked.name),
    );
  }

  Future<void> _upload(PermitAttachment kind) async {
    if (_model.busy) return;
    final isPhoto =
        kind == PermitAttachment.treePhotos ||
        kind == PermitAttachment.contextPhotos;

    try {
      String? url;
      if (isPhoto) {
        final source = await showImageSourceSheet(
          context,
          title: 'Add Photo',
        );
        if (!mounted || source == null) return;
        url = await _pickAndUploadImage(kind, source);
      } else {
        final source = await _askDocumentSource();
        if (!mounted || source == null) return;
        url = switch (source) {
          _DocumentSource.camera => await _pickAndUploadImage(
            kind,
            ImageSource.camera,
          ),
          _DocumentSource.gallery => await _pickAndUploadImage(
            kind,
            ImageSource.gallery,
          ),
          _DocumentSource.file => await _pickAndUploadFile(kind),
        };
      }
      if (url != null) _model.attach(kind, url);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Upload failed. Check your connection and try again.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) _model.setUploading(null);
    }
  }

  Future<void> _onContinue() async {
    switch (_step) {
      case 0:
        if (!(_applicantKey.currentState?.validate() ?? false)) {
          _warnIncomplete();
          return;
        }
        _goToStep(1);
      case 1:
        if (!(_treesKey.currentState?.validate() ?? false)) {
          _warnIncomplete();
          return;
        }
        _goToStep(2);
      case 2:
        final problem = _model.validateDocuments();
        if (problem != null) {
          showAppSnackBar(context, problem, type: AppMessageType.warning);
          return;
        }
        _goToStep(3);
      case 3:
        if (!(_reviewKey.currentState?.validate() ?? false)) return;
        await _submit();
    }
  }

  void _warnIncomplete() => showAppSnackBar(
    context,
    'Please complete the highlighted fields.',
    type: AppMessageType.warning,
  );

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showAppSnackBar(
        context,
        'Your session has expired. Please sign in again.',
        type: AppMessageType.error,
      );
      return;
    }

    _model.setSubmitting(true);
    try {
      await FirebaseFirestore.instance.collection('tree_cutting_permits').doc().set(
        _model.toFirestore(
          uid: user.uid,
          submittedAt: FieldValue.serverTimestamp(),
          historyTimestamp: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Application submitted. You can track it under My Submissions.',
        type: AppMessageType.success,
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not submit your application. Check your connection and try again.',
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) _model.setSubmitting(false);
    }
  }

  Widget _buildStep() => switch (_step) {
    0 => PermitApplicantStep(model: _model, formKey: _applicantKey),
    1 => PermitTreesStep(
      model: _model,
      formKey: _treesKey,
      onIdentifySpecies: _openSpeciesIdentify,
      onPickLocation: _pickLocation,
    ),
    2 => PermitDocumentsStep(model: _model, onUpload: _upload),
    _ => PermitReviewStep(
      model: _model,
      formKey: _reviewKey,
      onEditStep: _goToStep,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Tree Permit Application')),
        body: Column(
          children: [
            PermitStepHeader(titles: _stepTitles, currentStep: _step),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _buildStep(),
                  ),
                ),
              ),
            ),
            _BottomBar(
              model: _model,
              step: _step,
              lastStep: _stepTitles.length - 1,
              onBack: () => _goToStep(_step - 1),
              onContinue: _onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.model,
    required this.step,
    required this.lastStep,
    required this.onBack,
    required this.onContinue,
  });

  final TreeCuttingFormModel model;
  final int step;
  final int lastStep;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListenableBuilder(
                listenable: model,
                builder: (context, _) {
                  final isLast = step == lastStep;
                  return Row(
                    children: [
                      if (step > 0) ...[
                        OutlinedButton(
                          onPressed: model.busy ? null : onBack,
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: model.busy ? null : onContinue,
                          child: model.submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isLast ? 'Submit Application' : 'Continue'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
