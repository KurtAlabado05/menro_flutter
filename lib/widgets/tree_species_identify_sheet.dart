import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/tree_species_aliases.dart';
import '../models/species_identification_result.dart';
import '../services/cloudinary_image_service.dart';
import '../services/tree_species_identification_service.dart';

class TreeSpeciesIdentifySheet extends StatefulWidget {
  final CloudinaryImageService cloudinary;

  const TreeSpeciesIdentifySheet({
    super.key,
    required this.cloudinary,
  });

  static Future<SpeciesIdentificationResult?> show(
    BuildContext context, {
    required CloudinaryImageService cloudinary,
  }) {
    return showModalBottomSheet<SpeciesIdentificationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TreeSpeciesIdentifySheet(cloudinary: cloudinary),
    );
  }

  @override
  State<TreeSpeciesIdentifySheet> createState() =>
      _TreeSpeciesIdentifySheetState();
}

class _TreeSpeciesIdentifySheetState extends State<TreeSpeciesIdentifySheet> {
  final _identificationService = const TreeSpeciesIdentificationService();
  final _picker = ImagePicker();

  Uint8List? _leafBytes;
  Uint8List? _trunkBytes;
  String? _leafUrl;
  String? _trunkUrl;

  bool _isUploading = false;
  bool _isIdentifying = false;
  SpeciesIdentificationResult? _result;
  String? _errorMessage;

  bool get _hasAtLeastOnePhoto => _leafBytes != null || _trunkBytes != null;

  Future<void> _capturePhoto({required bool isLeaf}) async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = 'Camera permission is required to take photos.';
      });
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _errorMessage = null;
      _result = null;
      if (isLeaf) {
        _leafBytes = bytes;
        _leafUrl = null;
      } else {
        _trunkBytes = bytes;
        _trunkUrl = null;
      }
    });
  }

  Future<void> _pickImageFromGallery({required bool isLeaf}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _errorMessage = null;
      _result = null;
      if (isLeaf) {
        _leafBytes = bytes;
        _leafUrl = null;
      } else {
        _trunkBytes = bytes;
        _trunkUrl = null;
      }
    });
  }

  Future<void> _choosePhotoInput({required bool isLeaf}) async {
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

    if (choice == 'gallery') {
      await _pickImageFromGallery(isLeaf: isLeaf);
      return;
    }
    if (choice != 'file') return;

    try {
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
        if (isLeaf) {
          _leafBytes = bytes;
          _leafUrl = null;
        } else {
          _trunkBytes = bytes;
          _trunkUrl = null;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not load image file: $e');
    }
  }

  Future<void> _uploadEvidence() async {
    final uploads = <Future<void>>[];

    if (_leafBytes != null && _leafUrl == null) {
      uploads.add(() async {
        _leafUrl = await widget.cloudinary.uploadImage(
          bytes: _leafBytes!,
          fileName:
              'tree_cutting_speciesLeaf_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }());
    }

    if (_trunkBytes != null && _trunkUrl == null) {
      uploads.add(() async {
        _trunkUrl = await widget.cloudinary.uploadImage(
          bytes: _trunkBytes!,
          fileName:
              'tree_cutting_speciesTrunk_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }());
    }

    await Future.wait(uploads);
  }

  Future<void> _identify() async {
    if (!_hasAtLeastOnePhoto) {
      setState(() {
        _errorMessage = 'Capture at least one leaf or trunk photo.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _isIdentifying = false;
      _errorMessage = null;
    });

    try {
      await _uploadEvidence();

      final imageUrls = <String>[];
      final organs = <String>[];
      if (_leafUrl != null) {
        imageUrls.add(_leafUrl!);
        organs.add('leaf');
      }
      if (_trunkUrl != null) {
        imageUrls.add(_trunkUrl!);
        organs.add('bark');
      }

      setState(() {
        _isUploading = false;
        _isIdentifying = true;
      });

      final raw = await _identificationService.identifyFromUrls(
        evidencePhotoUrls: imageUrls,
        organs: organs,
      );

      final enrichedSuggestions = raw.suggestions
          .map(_identificationService.enrichSuggestion)
          .toList();
      final enrichedBest = raw.bestMatch != null
          ? _identificationService.enrichSuggestion(raw.bestMatch!)
          : (enrichedSuggestions.isNotEmpty ? enrichedSuggestions.first : null);

      setState(() {
        _result = SpeciesIdentificationResult(
          suggestions: enrichedSuggestions,
          bestMatch: enrichedBest,
          evidencePhotoUrls: imageUrls,
          identifiedAt: raw.identifiedAt,
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Identification unavailable. Please select species manually. ($e)';
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

  void _acceptSuggestion(SpeciesSuggestion suggestion) {
    final result = _result;
    if (result == null) return;
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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
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
                'Take clear photos of a leaf and/or trunk bark. '
                'AI will suggest a species — you can always change it manually.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 16),
              _PhotoCaptureTile(
                label: 'Leaf photo',
                icon: Icons.eco_outlined,
                previewBytes: _leafBytes,
                onCapture: () => _capturePhoto(isLeaf: true),
                onUpload: () => _choosePhotoInput(isLeaf: true),
                onClear: () => setState(() {
                  _leafBytes = null;
                  _leafUrl = null;
                  _result = null;
                }),
              ),
              const SizedBox(height: 10),
              _PhotoCaptureTile(
                label: 'Trunk / bark photo',
                icon: Icons.park_outlined,
                previewBytes: _trunkBytes,
                onCapture: () => _capturePhoto(isLeaf: false),
                onUpload: () => _choosePhotoInput(isLeaf: false),
                onClear: () => setState(() {
                  _trunkBytes = null;
                  _trunkUrl = null;
                  _result = null;
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isUploading || _isIdentifying)
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
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
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
    );
  }

  Widget _buildSuggestionCard(SpeciesSuggestion suggestion) {
    final isLowConfidence =
        suggestion.confidence < TreeSpeciesIdentificationService.lowConfidenceThreshold;

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
                color: isLowConfidence ? Colors.orange.shade800 : AppColors.primary,
              ),
            ),
            if (isLowConfidence)
              const Text(
                'Low confidence — please verify or choose manually.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            if (suggestion.matchedDropdownLabel != TreeSpeciesAliases.othersLabel)
              Text(
                'Matches: ${suggestion.matchedDropdownLabel}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _acceptSuggestion(suggestion),
                child: const Text('Use this species'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCaptureTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Uint8List? previewBytes;
  final VoidCallback onCapture;
  final VoidCallback onUpload;
  final VoidCallback onClear;

  const _PhotoCaptureTile({
    required this.label,
    required this.icon,
    required this.previewBytes,
    required this.onCapture,
    required this.onUpload,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (previewBytes != null)
                  const Text(
                    'Photo captured',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
              ],
            ),
          ),
          if (previewBytes != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
            ),
          if (previewBytes == null) ...
            [
              OutlinedButton(
                onPressed: onCapture,
                child: const Text('Camera'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Upload'),
              ),
            ]
          else
            OutlinedButton(
              onPressed: onCapture,
              child: const Text('Retake'),
            ),
        ],
      ),
    );
  }
}
