import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/tree_species_aliases.dart';
import '../models/species_identification_result.dart';
import '../models/photo_identification_error.dart';
import '../screens/report/report_camera_screen.dart';
import '../services/cloudinary_image_service.dart';
import '../services/tree_species_identification_service.dart';

class TreeSpeciesIdentifySheet extends StatefulWidget {
  final CloudinaryImageService cloudinary;
  final TreeSpeciesIdentificationService identificationService;
  final ImagePicker? imagePicker;

  const TreeSpeciesIdentifySheet({
    super.key,
    required this.cloudinary,
    this.identificationService = const TreeSpeciesIdentificationService(),
    this.imagePicker,
  });

  static Future<SpeciesIdentificationResult?> show(
    BuildContext context, {
    required CloudinaryImageService cloudinary,
    TreeSpeciesIdentificationService identificationService =
        const TreeSpeciesIdentificationService(),
  }) {
    return showModalBottomSheet<SpeciesIdentificationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TreeSpeciesIdentifySheet(
        cloudinary: cloudinary,
        identificationService: identificationService,
      ),
    );
  }

  @override
  State<TreeSpeciesIdentifySheet> createState() =>
      _TreeSpeciesIdentifySheetState();
}

class _TreeSpeciesIdentifySheetState extends State<TreeSpeciesIdentifySheet> {
  late final _identificationService = widget.identificationService;
  late final _picker = widget.imagePicker ?? ImagePicker();

  final List<_TreePhoto> _photos = [];

  bool _isUploading = false;
  bool _isIdentifying = false;
  SpeciesIdentificationResult? _result;
  String? _errorMessage;
  String _errorTitle = 'Could not analyze photos';
  bool _isPicking = false;
  bool get _busy => _isPicking || _isUploading || _isIdentifying;

  bool get _hasAtLeastOnePhoto => _photos.isNotEmpty;

  Future<void> _capturePhoto() async {
    if (_busy) return;
    setState(() => _isPicking = true);
    try {
      final photo = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (_) => const ReportCameraScreen()),
      );
      if (photo != null) await _addPhoto(photo);
    } catch (e, stack) {
      _photoLoadFailure(e, stack);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked == null || !mounted) return;

    await _addPhoto(picked);
  }

  Future<void> _addPhoto(XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _result = null;
      _photos.add(_TreePhoto(bytes));
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _choosePhotoInput() async {
    if (_busy) return;
    setState(() => _isPicking = true);
    try {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Choose Image File'),
                onTap: () => Navigator.pop(sheetContext, 'file'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (choice == 'gallery') {
        await _pickImageFromGallery();
        return;
      }
      if (choice != 'file') return;

      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final bytes = result?.files.singleOrNull?.bytes;
      if (bytes == null || !mounted) return;
      setState(() {
        _errorMessage = null;
        _result = null;
        _photos.add(_TreePhoto(bytes));
      });
    } catch (e, stack) {
      _photoLoadFailure(e, stack);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _photoLoadFailure(Object error, StackTrace stack) {
    debugPrint('Tree photo load failed: $error\n$stack');
    if (mounted) {
      setState(() {
        _errorTitle = 'Could not load photo';
        _errorMessage = 'Choose a readable JPG or PNG image and try again.';
      });
    }
  }

  Future<void> _uploadEvidence() async {
    final uploads = <Future<void>>[];

    for (var i = 0; i < _photos.length; i++) {
      final photo = _photos[i];
      if (photo.url != null) continue;
      uploads.add(() async {
        photo.url = await widget.cloudinary.uploadImage(
          bytes: photo.bytes,
          timeout: const Duration(seconds: 60),
          fileName:
              'tree_cutting_speciesPhoto${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }());
    }

    await Future.wait(uploads);
  }

  Future<void> _identify() async {
    if (_busy) return;
    if (!_hasAtLeastOnePhoto) {
      setState(() {
        _errorMessage = 'Capture at least one tree photo.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _isIdentifying = false;
      _errorMessage = null;
      _result = null;
    });

    try {
      await _uploadEvidence();
      if (!mounted) return;

      final imageUrls = [for (final photo in _photos) photo.url!];

      setState(() {
        _isUploading = false;
        _isIdentifying = true;
      });

      // Validate each image separately so a confidently recognized photo cannot mask an invalid one.
      SpeciesIdentificationResult? raw;
      for (var i = 0; i < imageUrls.length; i++) {
        if (!mounted) return;
        try {
          final identified = await _identificationService.identifyFromUrls(
            evidencePhotoUrls: [imageUrls[i]],
          );
          final best = identified.bestMatch;
          if (best == null ||
              !best.confidence.isFinite ||
              best.confidence <
                  TreeSpeciesIdentificationService.lowConfidenceThreshold ||
              best.confidence > 1) {
            throw const PhotoIdentificationException(
              PhotoIdentificationFailure.lowConfidence,
            );
          }
          raw ??= identified;
        } on PhotoIdentificationException catch (e) {
          throw PhotoIdentificationException(e.failure, photoIndex: i);
        }
      }
      if (!mounted || raw == null) return;
      final enrichedSuggestions = raw.suggestions
          .map(_identificationService.enrichSuggestion)
          .toList();
      final enrichedBest = raw.bestMatch != null
          ? _identificationService.enrichSuggestion(raw.bestMatch!)
          : (enrichedSuggestions.isNotEmpty ? enrichedSuggestions.first : null);
      final identifiedAt = raw.identifiedAt;

      setState(() {
        _result = SpeciesIdentificationResult(
          suggestions: enrichedSuggestions,
          bestMatch: enrichedBest,
          evidencePhotoUrls: imageUrls,
          identifiedAt: identifiedAt,
        );
      });
    } catch (e, stack) {
      debugPrint('Tree species identification failed: $e\n$stack');
      if (!mounted) return;
      final failure = e is PhotoIdentificationException
          ? e
          : const PhotoIdentificationException(
              PhotoIdentificationFailure.unavailable,
            );
      setState(() {
        _result = null;
        _errorTitle = failure.title;
        final prefix = failure.photoIndex == null
            ? ''
            : '${_labelForPhotoIndex(failure.photoIndex!)}: ';
        _errorMessage = '$prefix${failure.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isIdentifying = false;
        });
      }
    }
  }

  String _labelForPhotoIndex(int index) =>
      _photos.length > 1 ? 'Photo ${index + 1}' : 'Photo';

  void _acceptSuggestion(SpeciesSuggestion suggestion) {
    final result = _result;
    if (result == null ||
        _busy ||
        suggestion.confidence <
            TreeSpeciesIdentificationService.lowConfidenceThreshold ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    Navigator.pop(
      context,
      SpeciesIdentificationResult(
        suggestions: result.suggestions,
        bestMatch: suggestion,
        evidencePhotoUrls: result.evidencePhotoUrls,
        identifiedAt: result.identifiedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: SafeArea(
          child: SingleChildScrollView(
            child: AbsorbPointer(
              absorbing: _busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Identify Tree Species',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Capture or upload a clear photo of the tree (a leaf or bark '
                    'close-up works well). A single photo is enough, and you can '
                    'add more photos for better accuracy. Every selected photo '
                    'must pass recognition. Changing the species manually does '
                    'not bypass photo validation.',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  _PhotoCaptureTile(
                    photos: [for (final photo in _photos) photo.bytes],
                    validated: _result != null,
                    onCapture: _capturePhoto,
                    onUpload: _choosePhotoInput,
                    onRemove: _removePhoto,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_busy || !_hasAtLeastOnePhoto)
                          ? null
                          : _identify,
                      icon: _isUploading || _isIdentifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.biotech_outlined),
                      label: Text(
                        _isUploading
                            ? 'Uploading photos...'
                            : _isIdentifying
                            ? 'Analyzing plant...'
                            : 'Analyze photos',
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _errorTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_errorMessage!),
                            const SizedBox(height: 6),
                            const Text(
                              'Remove the uncertain photo and try a clearer one, or '
                              'analyze with just the photos that are recognized. At '
                              'least one recognized photo is required. Retry later '
                              'if the service is unavailable.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Suggestions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._result!.suggestions.take(3).map(_buildSuggestionCard),
                    const SizedBox(height: 8),
                    const Text(
                      'AI suggestion only. MENRO/DENR staff will verify during inspection.',
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(SpeciesSuggestion suggestion) {
    final isLowConfidence =
        suggestion.confidence <
        TreeSpeciesIdentificationService.lowConfidenceThreshold;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (suggestion.scientificName.isNotEmpty)
              Text(
                suggestion.scientificName,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${suggestion.confidencePercent}%',
              style: TextStyle(
                fontSize: 12,
                color: isLowConfidence
                    ? Colors.orange.shade800
                    : AppColors.primary,
              ),
            ),
            if (isLowConfidence)
              const Text(
                'Low confidence — please verify or choose manually.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            if (suggestion.matchedDropdownLabel !=
                TreeSpeciesAliases.othersLabel)
              Text(
                'Matches: ${suggestion.matchedDropdownLabel}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLowConfidence || _busy
                    ? null
                    : () => _acceptSuggestion(suggestion),
                child: const Text('Use this species'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single evidence photo captured or uploaded through the tree species
/// identification sheet. [url] is populated once the photo has been
/// uploaded to Cloudinary.
class _TreePhoto {
  _TreePhoto(this.bytes);
  final Uint8List bytes;
  String? url;
}

/// Consolidated camera/upload UI: a single control for adding tree photos,
/// instead of separate leaf and trunk/bark inputs. Users can add as many
/// photos as they like and remove any of them individually.
class _PhotoCaptureTile extends StatelessWidget {
  final List<Uint8List> photos;
  final bool validated;
  final VoidCallback onCapture;
  final VoidCallback onUpload;
  final void Function(int index) onRemove;

  const _PhotoCaptureTile({
    required this.photos,
    required this.validated,
    required this.onCapture,
    required this.onUpload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhotos = photos.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tree photo',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      !hasPhotos
                          ? 'No photo added yet'
                          : validated
                          ? 'Photo${photos.length > 1 ? 's' : ''} checked'
                          : 'Photo${photos.length > 1 ? 's' : ''} selected - not yet checked',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasPhotos && validated
                            ? AppColors.primary
                            : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPhotos) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          photos[i],
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.eco_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton(
                          onPressed: () => onRemove(i),
                          tooltip: 'Remove photo',
                          icon: const Icon(Icons.cancel, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: onCapture, child: const Text('Camera')),
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Upload'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
