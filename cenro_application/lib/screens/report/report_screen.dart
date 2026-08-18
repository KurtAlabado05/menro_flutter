import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_image_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import 'report_location_picker.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart' as app_auth_provider;
import '../../providers/report_provider.dart';
import '../../widgets/custom_textfield.dart';
import 'picked_image.dart';
import '../submissions/my_submissions_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // 🟢 Individual Controllers for Location Details Data
  final _fullAddressController = TextEditingController();
  final _barangayController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();

  final _reporterNameController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedCategory = 'Illegal Dumping of Solid Waste';
  final List<String> _categories = [
    'Illegal Dumping of Solid Waste',
    'Waterway Pollution',
    'Improper Liquid/Wastewater Disposal',
    'Open Burning of Waste',
    'Public smoking violation',
    'Littering / Public vandalism',
  ];

  final List<PickedImage> _selectedImages = [];

  bool _isUploadingImages = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;

  final Map<String, IconData> _categoryIcons = {
    'Illegal Dumping of Solid Waste': Icons.warning_amber_outlined,
    'Waterway Pollution': Icons.water_outlined,
    'Improper Liquid/Wastewater Disposal': Icons.water_drop_outlined,
    'Open Burning of Waste': Icons.local_fire_department_outlined,
    'Public smoking violation': Icons.smoke_free,
    'Littering / Public vandalism': Icons.report_outlined,
  };

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
    _autoFetchLocation();
  }

  // 🟢 Prefill Account Information cleanly (Synced dynamically from tree cutting system)
  void _prefillFromAccount(app_auth_provider.AuthProvider auth) {
    final user = auth.user;
    if (user == null) return;

    final dynamicUser = user as dynamic;

    if (_reporterNameController.text.trim().isEmpty) {
      final role = dynamicUser.role as String?;
      String? extractedName;

      if (role == 'organization') {
        extractedName =
            dynamicUser.orgName ?? dynamicUser.companyName as String?;
      } else {
        try {
          final nameDetails = dynamicUser.nameDetails;
          if (nameDetails is Map<String, dynamic> || nameDetails is Map) {
            final String first =
                (nameDetails['firstName'] as String?)?.trim() ?? '';
            final String last =
                (nameDetails['lastName'] as String?)?.trim() ?? '';
            final String middle =
                (nameDetails['middleName'] as String?)?.trim() ?? '';

            String middleInitial = '';
            if (middle.isNotEmpty) {
              middleInitial = '${middle[0].toUpperCase()}. ';
            }

            final combined = '$first $middleInitial$last'.trim();
            if (combined.isNotEmpty) {
              extractedName = combined;
            }
          }
        } catch (e) {
          extractedName = null;
        }
      }

      if (extractedName != null && extractedName.trim().isNotEmpty) {
        _reporterNameController.text = extractedName.trim();
      } else if (user.name.isNotEmpty) {
        _reporterNameController.text = user.name;
      }
    }

    if (_contactController.text.trim().isEmpty) {
      final phone = user.phoneNumber ?? dynamicUser.phone as String?;
      if (phone != null && phone.trim().isNotEmpty) {
        _contactController.text = phone.trim();
      }
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
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latitude = position.latitude;
      _longitude = position.longitude;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          if (mounted) {
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
        }
      } catch (_) {
        if (mounted) {
          _fullAddressController.text =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              _BottomSheetTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              _BottomSheetTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(
        () => _selectedImages.add(PickedImage(file: picked, bytes: bytes)),
      );
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
      final image = _selectedImages[i];
      if (image.bytes == null) continue;
      try {
        final url = await cloudinary.uploadImage(
          bytes: image.bytes!,
          fileName: 'reports_${reportId}_image_$i.jpg',
        );
        urls.add(url);
      } catch (e) {
        debugPrint('❌ Cloudinary upload failed: $e');
        rethrow;
      }
    }
    return urls;
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _buildPreviewDialog(),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<app_auth_provider.AuthProvider>();
    final reportProvider = context.read<ReportProvider>();
    setState(() => _isUploadingImages = true);

    try {
      final tempId = 'r${DateTime.now().millisecondsSinceEpoch}';
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages(tempId);
      }

      final report = ReportModel(
        id: tempId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,

        // 🟢 Using clean distinct data parameters for structured storage
        location: _fullAddressController.text.trim().isEmpty
            ? 'Unknown'
            : _fullAddressController.text.trim(),
        barangay: _barangayController.text.trim().isEmpty
            ? null
            : _barangayController.text.trim(),
        sitio: _streetController.text.trim().isEmpty
            ? null
            : _streetController.text.trim(),
        landmark: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),

        latitude: _latitude,
        longitude: _longitude,
        severity: _severityForCategory(_selectedCategory),
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
        imageUrls: imageUrls,
        submittedBy: auth.user!.id,
        submittedByName: _reporterNameController.text.trim().isEmpty
            ? auth.user!.name
            : _reporterNameController.text.trim(),
        submittedByContact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        isAnonymous: false,
        submittedAt: DateTime.now(),
        statusHistory: [
          ReportStatusUpdate(
            status: 'pending',
            message: 'Report submitted successfully.',
            timestamp: DateTime.now(),
          ),
        ],
      );

      await reportProvider.submitReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report submitted successfully!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        _titleController.clear();
        _descController.clear();
        _fullAddressController.clear();
        _barangayController.clear();
        _streetController.clear();
        _landmarkController.clear();
        _reporterNameController.clear();
        _contactController.clear();

        setState(() {
          _selectedCategory = _categories.first;
          _selectedImages.clear();
          _latitude = null;
          _longitude = null;
        });
        _autoFetchLocation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Widget _buildPreviewDialog() {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Preview Report',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _previewRow(
                Icons.category_outlined,
                'Category',
                _selectedCategory,
              ),
              const SizedBox(height: 10),
              _previewRow(
                Icons.home_work_outlined,
                'Barangay',
                _barangayController.text.isNotEmpty
                    ? _barangayController.text
                    : '-',
              ),
              const SizedBox(height: 10),
              _previewRow(
                Icons.add_road,
                'Street Name',
                _streetController.text.isNotEmpty
                    ? _streetController.text
                    : '-',
              ),
              const SizedBox(height: 10),
              _previewRow(
                Icons.pin_drop_outlined,
                'Landmark',
                _landmarkController.text.isNotEmpty
                    ? _landmarkController.text
                    : '-',
              ),
              const SizedBox(height: 10),
              _previewRow(
                Icons.location_on_outlined,
                'Full Details',
                _fullAddressController.text,
              ),
              const SizedBox(height: 10),
              _previewRow(
                Icons.edit_note,
                'Description',
                _descController.text.trim(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _previewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth_provider.AuthProvider>();
    _prefillFromAccount(auth);

    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final isWorking = _isUploadingImages || provider.isLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 1: PHOTO EVIDENCE
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.photo_camera_outlined,
                          label: 'Photo Evidence',
                          subtitle: 'Attach photos of the issue',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _selectedImages.length) {
                                return GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(
                                          0.25,
                                        ),
                                      ),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: AppColors.primary,
                                          size: 26,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Add Photo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _selectedImages[index].bytes!,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // SECTION 2: REPORT DETAILS
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.assignment_outlined,
                          label: 'Report Details',
                          subtitle: 'Describe the issue clearly',
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _titleController,
                          label: 'Report Title',
                          prefixIcon: Icons.title,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _categories.contains(_selectedCategory)
                              ? _selectedCategory
                              : null,
                          hint: const Text('Select Category'),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(
                              _categoryIcons[_selectedCategory] ??
                                  Icons.category_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          items: _categories.map((val) {
                            return DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategory = val!),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _descController,
                          label: 'Describe the issue in detail...',
                          prefixIcon: Icons.edit_note,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🟢 SECTION 3: RESTRUCTURED INDIVIDUAL LOCATION DETAILS FIELDS
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _SectionTitle(
                                icon: Icons.location_on_outlined,
                                label: 'Incident Location',
                                subtitle:
                                    'Tap map icon to select precise coordinates',
                              ),
                            ),
                            _isFetchingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: _autoFetchLocation,
                                        tooltip: 'Refresh GPS',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.map,
                                          color: AppColors.primary,
                                        ),
                                        tooltip: 'Open Interactive Map Picker',
                                        onPressed: () async {
                                          final result =
                                              await Navigator.push<
                                                Map<String, dynamic>
                                              >(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ReportLocationPickerScreen(
                                                        initialLat: _latitude,
                                                        initialLng: _longitude,
                                                      ),
                                                ),
                                              );
                                          if (result != null && mounted) {
                                            setState(() {
                                              _latitude =
                                                  result['lat'] as double?;
                                              _longitude =
                                                  result['lng'] as double?;
                                              _fullAddressController.text =
                                                  (result['address']
                                                      as String?) ??
                                                  '';
                                              _barangayController.text =
                                                  (result['barangay']
                                                      as String?) ??
                                                  '';
                                              _streetController.text =
                                                  (result['street']
                                                      as String?) ??
                                                  '';
                                              _landmarkController.text =
                                                  (result['landmark']
                                                      as String?) ??
                                                  '';
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _barangayController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Barangay',
                                  prefixIcon: const Icon(
                                    Icons.home_work_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Barangay selection is required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _streetController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Street / Sitio',
                                  prefixIcon: const Icon(
                                    Icons.add_road,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _landmarkController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Nearest Landmark',
                            prefixIcon: const Icon(
                              Icons.pin_drop_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _fullAddressController,
                          maxLines: 2,
                          readOnly: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Complete Address Details',
                            prefixIcon: const Icon(
                              Icons.explore_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // SECTION 4: REPORTER INFORMATION
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reporter Information',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reporterNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle: const TextStyle(fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _contactController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Contact Number',
                            labelStyle: const TextStyle(fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MySubmissionsScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: AppColors.primary.withOpacity(0.35),
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.track_changes_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Track my report complaints',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isWorking ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.5,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isWorking
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isUploadingImages
                                      ? 'Uploading Images...'
                                      : 'Submitting...',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Report',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Sub-widgets layout
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.subtitle,
  });
  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomSheetTile extends StatelessWidget {
  const _BottomSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textGrey,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}
