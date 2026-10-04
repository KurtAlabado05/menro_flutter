import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';
import '../providers/auth_provider.dart' as app_auth_provider;
import '../services/cloudinary_image_service.dart';
import '../services/location/device_location_service.dart';
import '../services/tree_species_identification_service.dart';
import '../models/photo_identification_error.dart';
import '../models/report_location.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/section_widgets.dart';
import '../widgets/tree_species_identify_sheet.dart';
import 'report/report_camera_screen.dart';
import 'report/report_location_picker.dart';
import 'tree_cutting/tree_cutting_form_model.dart';
import 'tree_cutting/widgets/permit_applicant_step.dart';
import 'tree_cutting/widgets/permit_documents_step.dart';
import 'tree_cutting/widgets/permit_review_step.dart';
import 'tree_cutting/widgets/permit_step_header.dart';
import 'tree_cutting/widgets/permit_trees_step.dart';

enum _DocumentSource { camera, gallery, file }

class TreeCuttingApplicationScreen extends StatefulWidget {
  const TreeCuttingApplicationScreen({
    super.key,
    this.identificationService = const TreeSpeciesIdentificationService(),
    this.model,
    this.submitApplication,
    this.currentUid,
    this.imagePicker,
    this.cloudinary,
    this.captureOnSitePhoto,
    this.onSiteLocation,
  });

  final TreeSpeciesIdentificationService identificationService;
  final TreeCuttingFormModel? model;
  final Future<void> Function(Map<String, dynamic>)? submitApplication;
  final String? Function()? currentUid;
  final ImagePicker? imagePicker;
  final CloudinaryImageService? cloudinary;

  /// Live-camera capture for on-site photos; never a gallery picker.
  final Future<XFile?> Function(BuildContext context)? captureOnSitePhoto;

  /// Fresh GPS fix read right after an on-site capture.
  final Future<LocationFix> Function()? onSiteLocation;

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

  late final TreeCuttingFormModel _model =
      widget.model ?? TreeCuttingFormModel();
  final GlobalKey<FormState> _applicantKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _treesKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _reviewKey = GlobalKey<FormState>();
  final ScrollController _scroll = ScrollController();

  late final CloudinaryImageService _cloudinary =
      widget.cloudinary ??
      const CloudinaryImageService(
        cloudName: 'dfo5l4d4t',
        uploadPreset: 'flutter_upload_preset',
      );

  int _step = 0;
  bool _allowPop = false;
  bool _confirmingExit = false;

  @override
  void initState() {
    super.initState();
    _model.prefillFrom(context.read<app_auth_provider.AuthProvider>().user);
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.model == null) _model.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (_model.busy) return;
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _confirmExit() async {
    if (_model.busy || _confirmingExit || _allowPop) return;
    if (!_model.hasUserInput) {
      await _leave();
      return;
    }
    _confirmingExit = true;
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
    _confirmingExit = false;
    if (discard == true && mounted) await _leave();
  }

  Future<void> _leave() async {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    // Rebuild PopScope before navigating; never pop from its blocked-pop callback.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSpeciesIdentify() async {
    final result = await TreeSpeciesIdentifySheet.show(
      context,
      cloudinary: _cloudinary,
      identificationService: widget.identificationService,
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
    final result = await Navigator.push<ReportLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportLocationPickerScreen(
          initialLat: _model.latitude,
          initialLng: _model.longitude,
        ),
      ),
    );
    if (result == null || !mounted) return;
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
    final picked = await (widget.imagePicker ?? ImagePicker()).pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    _model.setUploading(kind);
    final bytes = await picked.readAsBytes();
    return _cloudinary.uploadImage(
      bytes: bytes,
      timeout: const Duration(seconds: 60),
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

    _model.photoError = null;
    _model.setUploading(kind);
    var offerOnSite = false;
    try {
      String? url;
      if (isPhoto) {
        final source = await showImageSourceSheet(context, title: 'Add Photo');
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
      if (!mounted || url == null) return;
      if (kind == PermitAttachment.treePhotos) {
        await widget.identificationService.validateTreePhotos([url]);
        if (!mounted) return;
      }
      _model.attach(
        kind,
        url,
        photoValidated: kind == PermitAttachment.treePhotos,
      );
    } catch (error, stack) {
      debugPrint('Tree permit attachment failed: $error\n$stack');
      if (mounted) {
        final message = error is PhotoIdentificationException
            ? error.message
            : 'Upload failed. Check your connection and try again.';
        _model.photoError = message;
        showAppSnackBar(context, message, type: AppMessageType.error);
        offerOnSite = kind == PermitAttachment.treePhotos &&
            error is PhotoIdentificationException &&
            error.allowsOnSiteFallback;
      }
    } finally {
      if (mounted) _model.setUploading(null);
    }
    if (offerOnSite && mounted) await _offerOnSitePhoto();
  }

  Future<void> _offerOnSitePhoto() async {
    final takePhoto = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tree has no leaves or is dead?'),
        content: const Text(
          'Leafless, dead, or cut trees are often impossible to identify from a photo. '
          'You can take a live photo while standing at the tree you pinned. '
          'Your location is checked against the pin, and MENRO will confirm the '
          'species during the required site inspection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Try another photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Take on-site photo'),
          ),
        ],
      ),
    );
    if (takePhoto == true && mounted) await _takeOnSitePhoto();
  }

  static const double _onSiteMaxAccuracyMeters = 50;
  static const double _onSiteMaxDistanceMeters = 100;

  Future<LocationFix> _deviceOnSiteFix() async {
    try {
      return await const DeviceLocationService().currentFix();
    } catch (error) {
      debugPrint('On-site GPS fix failed: $error');
      throw const PhotoIdentificationException(
        PhotoIdentificationFailure.onSiteLocationUnavailable,
      );
    }
  }

  /// Live capture at the tree for species that cannot be recognized. The
  /// server still runs recognition and flags the permit for inspection only
  /// when recognition is uncertain and the GPS fix matches the pinned tree.
  Future<void> _takeOnSitePhoto() async {
    if (_model.busy) return;
    const kind = PermitAttachment.treePhotos;
    _model.photoError = null;
    try {
      final treeLatitude = _model.latitude;
      final treeLongitude = _model.longitude;
      if (treeLatitude == null || treeLongitude == null) {
        throw const PhotoIdentificationException(
          PhotoIdentificationFailure.onSiteTreeNotPinned,
        );
      }
      final locate = widget.onSiteLocation ?? _deviceOnSiteFix;
      if (widget.onSiteLocation == null) {
        // Ask for location before the user takes the photo, not after.
        final availability = await const DeviceLocationService()
            .checkAvailability();
        if (availability != LocationAvailability.available) {
          throw const PhotoIdentificationException(
            PhotoIdentificationFailure.onSiteLocationUnavailable,
          );
        }
        if (!mounted) return;
      }
      _model.setUploading(kind);
      final photo = await (widget.captureOnSitePhoto?.call(context) ??
          Navigator.push<XFile>(
            context,
            MaterialPageRoute(builder: (_) => const ReportCameraScreen()),
          ));
      if (!mounted || photo == null) return;
      final capturedAt = DateTime.now();
      final fix = await locate();
      if (!mounted) return;
      if (fix.accuracyMeters > _onSiteMaxAccuracyMeters ||
          capturedAt.difference(fix.timestamp).abs() >
              const Duration(minutes: 2)) {
        throw const PhotoIdentificationException(
          PhotoIdentificationFailure.onSiteGpsUnreliable,
        );
      }
      final distance = Geolocator.distanceBetween(
        fix.latitude,
        fix.longitude,
        treeLatitude,
        treeLongitude,
      );
      if (distance > _onSiteMaxDistanceMeters) {
        throw const PhotoIdentificationException(
          PhotoIdentificationFailure.onSiteTooFar,
        );
      }
      final url = await _cloudinary.uploadImage(
        bytes: await photo.readAsBytes(),
        timeout: const Duration(seconds: 60),
        fileName: _fileName(kind, photo.name),
      );
      if (!mounted) return;
      final capture = OnSiteTreeCapture(
        url: url,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyMeters: fix.accuracyMeters,
        capturedAt: capturedAt,
      );
      final validation = await widget.identificationService.validateTreePhotos(
        [url],
        onSiteCaptures: [capture],
        treeLatitude: treeLatitude,
        treeLongitude: treeLongitude,
      );
      if (!mounted) return;
      _model.attach(
        kind,
        url,
        photoValidated: true,
        onSiteCapture: capture,
        speciesUnverified: validation.requiresInspection,
      );
      showAppSnackBar(
        context,
        validation.requiresInspection
            ? 'On-site photo added. The species will be confirmed during the site inspection.'
            : 'Photo added. The tree was recognized.',
        type: validation.requiresInspection
            ? AppMessageType.warning
            : AppMessageType.success,
      );
    } catch (error, stack) {
      debugPrint('On-site tree photo failed: $error\n$stack');
      if (mounted) {
        final message = error is PhotoIdentificationException
            ? error.message
            : 'Upload failed. Check your connection and try again.';
        _model.photoError = message;
        showAppSnackBar(context, message, type: AppMessageType.error);
      }
    } finally {
      if (mounted) _model.setUploading(null);
    }
  }

  Future<void> _onContinue() async {
    if (_model.busy) return;
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
    if (_model.busy) return;
    final problem = _model.validateDocuments();
    if (problem != null || !_model.declarationChecked) {
      showAppSnackBar(
        context,
        problem ?? 'Confirm the declaration before submitting.',
        type: AppMessageType.warning,
      );
      return;
    }
    final uid = widget.currentUid != null
        ? widget.currentUid!()
        : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      showAppSnackBar(
        context,
        'Your session has expired. Please sign in again.',
        type: AppMessageType.error,
      );
      return;
    }

    _model.setSubmitting(true);
    _model.photoError = null;
    try {
      final photos = List<String>.of(_model.treePhotoUrls);
      final validation = await widget.identificationService.validateTreePhotos(
        photos,
        onSiteCaptures: [
          for (final url in photos)
            if (_model.onSiteTreeCaptures[url] case final capture?) capture,
        ],
        treeLatitude: _model.latitude,
        treeLongitude: _model.longitude,
      );
      if (!mounted) return;
      _model.applyTreePhotoValidation(validation);
      final data = _model.toFirestore(
        uid: uid,
        submittedAt: FieldValue.serverTimestamp(),
        historyTimestamp: Timestamp.now(),
      );
      if (widget.submitApplication != null) {
        await widget.submitApplication!(data);
      } else {
        await FirebaseFirestore.instance
            .collection('tree_cutting_permits')
            .doc()
            .set(data);
      }
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Application submitted. You can track it under My Submissions.',
        type: AppMessageType.success,
      );
      await _leave();
    } catch (error, stack) {
      debugPrint('Tree permit submission failed: $error\n$stack');
      if (!mounted) return;
      final message = switch (error) {
        PhotoIdentificationException() => error.message,
        FirebaseException(code: 'permission-denied') =>
          'The application was not accepted. Your draft is kept. Revalidate the photos and retry; if this continues, contact MENRO.',
        FirebaseException(code: 'unauthenticated') =>
          'Your session has expired. Your draft is kept. Sign in again before submitting.',
        _ =>
          'Could not submit your application. Your draft is kept. Check your connection and try again.',
      };
      _model.photoError = message;
      showAppSnackBar(context, message, type: AppMessageType.error);
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
    2 => PermitDocumentsStep(
      model: _model,
      onUpload: _upload,
      onTakeOnSitePhoto: _takeOnSitePhoto,
    ),
    _ => PermitReviewStep(
      model: _model,
      formKey: _reviewKey,
      onEditStep: _goToStep,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _confirmExit();
          });
        }
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListenableBuilder(
                      listenable: _model,
                      builder: (_, _) => AbsorbPointer(
                        absorbing: _model.busy,
                        child: _buildStep(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          model: _model,
          step: _step,
          lastStep: _stepTitles.length - 1,
          onBack: () => _goToStep(_step - 1),
          onContinue: _onContinue,
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
            heightFactor: 1,
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
                              : Text(
                                  isLast ? 'Submit Application' : 'Continue',
                                ),
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
