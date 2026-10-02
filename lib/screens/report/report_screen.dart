import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_image_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import 'report_location_picker.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart' as app_auth_provider;
import '../../providers/report_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/section_widgets.dart';
import '../submissions/my_submissions_screen.dart';
import 'picked_image.dart';
import 'widgets/report_location_card.dart';
import 'widgets/report_photo_strip.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final _fullAddressController = TextEditingController();
  final _barangayController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();

  final _reporterNameController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedCategory = _categories.first;
  static const List<String> _categories = [
    'Illegal Dumping of Solid Waste',
    'Waterway Pollution',
    'Improper Liquid/Wastewater Disposal',
    'Open Burning of Waste',
    'Public smoking violation',
    'Littering / Public vandalism',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'Illegal Dumping of Solid Waste': Icons.warning_amber_outlined,
    'Waterway Pollution': Icons.water_outlined,
    'Improper Liquid/Wastewater Disposal': Icons.water_drop_outlined,
    'Open Burning of Waste': Icons.local_fire_department_outlined,
    'Public smoking violation': Icons.smoke_free,
    'Littering / Public vandalism': Icons.report_outlined,
  };

  final List<PickedImage> _selectedImages = [];

  bool _isUploadingImages = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;

  bool get _hasInput =>
      _titleController.text.trim().isNotEmpty ||
      _descController.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty;

  int _severityForCategory(String category) {
    switch (category.trim()) {
      case 'Littering / Public vandalism':
        return 1;
      case 'Public smoking violation':
        return 2;
      case 'Waterway Pollution':
        return 3;
      case 'Improper Liquid/Wastewater Disposal':
      case 'Open Burning of Waste':
        return 4;
      case 'Illegal Dumping of Solid Waste':
        return 5;
      default:
        return 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _prefillFromAccount();
    _autoFetchLocation();
  }

  void _prefillFromAccount() {
    final user = context.read<app_auth_provider.AuthProvider>().user;
    if (user == null) return;

    _reporterNameController.text = user.contextualName;
    final phone = user.phoneNumber;
    if (phone != null && phone.trim().isNotEmpty) {
      _contactController.text = phone.trim();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _fullAddressController.dispose();
    _barangayController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _reporterNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _autoFetchLocation() async {
    if (mounted) setState(() => _isFetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Location services are off. Turn them on or pick the spot on the map.',
            type: AppMessageType.warning,
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Location permission is off. You can still pick the spot on the map.',
            type: AppMessageType.warning,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _barangayController.text = place.subLocality ?? '';
            _streetController.text = place.street ?? '';
            _fullAddressController.text = [
              place.street,
              place.subLocality,
              place.locality,
              place.administrativeArea,
            ].where((p) => p != null && p.isNotEmpty).join(', ');
          });
        }
      } catch (_) {
        if (mounted) {
          _fullAddressController.text =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not get your location. Pick the spot on the map instead.',
          type: AppMessageType.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportLocationPickerScreen(
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result['lat'] as double?;
      _longitude = result['lng'] as double?;
      _fullAddressController.text = (result['address'] as String?) ?? '';
      _barangayController.text = (result['barangay'] as String?) ?? '';
      _streetController.text = (result['street'] as String?) ?? '';
      _landmarkController.text = (result['landmark'] as String?) ?? '';
    });
  }

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(
        () => _selectedImages.add(PickedImage(file: picked, bytes: bytes)),
      );
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not open the camera or gallery. Check app permissions.',
          type: AppMessageType.error,
        );
      }
    }
  }

  void _removeImage(int index) =>
      setState(() => _selectedImages.removeAt(index));

  Future<List<String>> _uploadImages(String reportId) async {
    final cloudinary = CloudinaryImageService(
      cloudName: 'dfo5l4d4t',
      uploadPreset: 'flutter_upload_preset',
    );

    final urls = <String>[];
    for (int i = 0; i < _selectedImages.length; i++) {
      final bytes = _selectedImages[i].bytes;
      if (bytes == null) continue;
      urls.add(
        await cloudinary.uploadImage(
          bytes: bytes,
          fileName: 'reports_${reportId}_image_$i.jpg',
        ),
      );
    }
    return urls;
  }

  String? _nullIfEmpty(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  ReportModel _buildReport({
    required String id,
    required String userId,
    required String userName,
    required DateTime submittedAt,
    List<String>? imageUrls,
  }) {
    final address = _fullAddressController.text.trim();
    final reporterName = _reporterNameController.text.trim();
    final isFinal = imageUrls != null;

    return ReportModel(
      id: id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      location: address.isEmpty ? 'Unknown' : address,
      barangay: _nullIfEmpty(_barangayController),
      sitio: _nullIfEmpty(_streetController),
      landmark: _nullIfEmpty(_landmarkController),
      latitude: _latitude,
      longitude: _longitude,
      severity: _severityForCategory(_selectedCategory),
      imageUrl: isFinal && imageUrls.isNotEmpty ? imageUrls.first : null,
      imageUrls: imageUrls ?? const [],
      submittedBy: userId,
      submittedByName: reporterName.isEmpty ? userName : reporterName,
      submittedByContact: _nullIfEmpty(_contactController),
      isAnonymous: false,
      submittedAt: submittedAt,
      statusHistory: isFinal
          ? [
              ReportStatusUpdate(
                status: 'pending',
                message: 'Report submitted successfully.',
                timestamp: DateTime.now(),
              ),
            ]
          : const [],
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      showAppSnackBar(
        context,
        'Please fix the highlighted fields.',
        type: AppMessageType.warning,
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      showAppSnackBar(
        context,
        'Please set the incident location using GPS or the map picker.',
        type: AppMessageType.warning,
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      showAppSnackBar(
        context,
        'Please attach at least one photo of the issue.',
        type: AppMessageType.warning,
      );
      return;
    }

    final auth = context.read<app_auth_provider.AuthProvider>();
    final user = auth.user;
    if (user == null) {
      showAppSnackBar(
        context,
        'You must be signed in to submit a report.',
        type: AppMessageType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: _buildPreviewDialog,
    );
    if (confirmed != true || !mounted) return;

    final reportProvider = context.read<ReportProvider>();
    setState(() => _isUploadingImages = true);

    try {
      final tempId = 'r${DateTime.now().millisecondsSinceEpoch}';
      final submittedAt = DateTime.now();

      final nearbyReport = await reportProvider.findNearbyActiveReport(
        _buildReport(
          id: tempId,
          userId: user.id,
          userName: user.name,
          submittedAt: submittedAt,
        ),
      );
      if (nearbyReport != null) {
        await _offerSupport(reportProvider, nearbyReport);
        return;
      }

      final imageUrls = await _uploadImages(tempId);
      await reportProvider.submitReport(
        _buildReport(
          id: tempId,
          userId: user.id,
          userName: user.name,
          submittedAt: submittedAt,
          imageUrls: imageUrls,
        ),
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Report submitted successfully!',
        type: AppMessageType.success,
        action: SnackBarAction(
          label: 'Track',
          textColor: Colors.white,
          onPressed: _openMySubmissions,
        ),
      );
      _resetForm();
    } on DuplicateReportException catch (e) {
      await _offerSupport(reportProvider, e.existingReport);
    } catch (e) {
      debugPrint('Report submit failed: $e');
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not submit your report. Check your connection and try again.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _offerSupport(
    ReportProvider provider,
    ReportModel existing,
  ) async {
    final wantsToSupport = await _showNearbyReportDialog(existing);
    if (wantsToSupport != true) return;
    await provider.addMeToo(existing.id);
    if (mounted) {
      showAppSnackBar(
        context,
        'Your support was added to the nearby report.',
        type: AppMessageType.success,
      );
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descController.clear();
    _fullAddressController.clear();
    _barangayController.clear();
    _streetController.clear();
    _landmarkController.clear();
    setState(() {
      _selectedCategory = _categories.first;
      _selectedImages.clear();
      _latitude = null;
      _longitude = null;
    });
    _formKey.currentState?.reset();
    _autoFetchLocation();
  }

  void _openMySubmissions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
    );
  }

  Future<bool?> _showNearbyReportDialog(ReportModel report) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('A nearby report already exists'),
        content: Text(
          'There is an active ${report.category.toLowerCase()} report at '
          '${report.location}. Is this the same issue you want to report?\n\n'
          'Choose “Me Too” to increase its priority instead of creating a duplicate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.thumb_up_outlined),
            label: const Text('Me Too'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewDialog(BuildContext dialogContext) {
    final photos = _selectedImages.length;
    return AlertDialog(
      title: const Text('Review your report'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailRow(
                label: 'Title',
                value: _titleController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Category',
                value: _selectedCategory,
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Barangay',
                value: _barangayController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Street',
                value: _streetController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Landmark',
                value: _landmarkController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Address',
                value: _fullAddressController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Description',
                value: _descController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Photos',
                value: '$photos attached',
                labelWidth: 90,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this report?'),
        content: const Text('What you entered so far will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final isWorking =
        _isUploadingImages ||
        context.select<ReportProvider, bool>((p) => p.isLoading);

    return PopScope(
      canPop: !_hasInput || isWorking,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            icon: Icons.photo_camera_outlined,
                            label: 'Photo Evidence',
                            subtitle: 'At least one photo is required',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ReportPhotoStrip(
                            images: _selectedImages,
                            onAdd: _pickImage,
                            onRemove: _removeImage,
                            enabled: !isWorking,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            icon: Icons.assignment_outlined,
                            label: 'Report Details',
                            subtitle: 'Describe the issue clearly',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CustomTextField(
                            controller: _titleController,
                            label: 'Report Title',
                            prefixIcon: Icons.title,
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Report title is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            label: 'Report category: $_selectedCategory',
                            button: true,
                            enabled: true,
                            onTap: () {},
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(
                                  _categoryIcons[_selectedCategory] ??
                                      Icons.category_outlined,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              items: [
                                for (final category in _categories)
                                  DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CustomTextField(
                            controller: _descController,
                            label: 'Describe the issue in detail',
                            prefixIcon: Icons.edit_note,
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                            validator: (v) => v == null || v.trim().length < 10
                                ? 'Please provide a description (min. 10 characters)'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReportLocationCard(
                      barangayController: _barangayController,
                      streetController: _streetController,
                      landmarkController: _landmarkController,
                      addressController: _fullAddressController,
                      isFetching: _isFetchingLocation,
                      hasCoordinates: _latitude != null && _longitude != null,
                      onRefreshGps: _autoFetchLocation,
                      onPickOnMap: _pickOnMap,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            icon: Icons.person_outline,
                            label: 'Reporter Information',
                            subtitle: 'Prefilled from your account',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CustomTextField(
                            controller: _reporterNameController,
                            label: 'Full Name',
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Full name is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CustomTextField(
                            controller: _contactController,
                            label: 'Contact Number',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Contact number is required';
                              }
                              final digitsOnly = v.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (digitsOnly.length < 10) {
                                return 'Enter a valid contact number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: isWorking ? null : _submitReport,
                      icon: isWorking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isWorking
                            ? (_isUploadingImages
                                  ? 'Uploading images...'
                                  : 'Submitting...')
                            : 'Submit Report',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: isWorking ? null : _openMySubmissions,
                      icon: const Icon(Icons.track_changes_outlined, size: 18),
                      label: const Text('Track my reports'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
