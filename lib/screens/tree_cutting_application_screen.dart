import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/tree_species_aliases.dart';
import '../../models/species_identification_result.dart';
import '../../services/cloudinary_image_service.dart';
import '../../providers/auth_provider.dart' as app_auth_provider;
import '../../widgets/tree_species_identify_sheet.dart';
import 'report/report_location_picker.dart';
import 'tree_cutting/tree_cutting_justification_guidelines_screen.dart';

enum _UploadSource { camera, gallery, file }

class TreeCuttingApplicationScreen extends StatefulWidget {
  const TreeCuttingApplicationScreen({super.key});

  @override
  State<TreeCuttingApplicationScreen> createState() =>
      _TreeCuttingApplicationScreenState();
}

class _TreeCuttingApplicationScreenState
    extends State<TreeCuttingApplicationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Applicant information controllers
  final TextEditingController _applicantNameController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Scope Selection Parameters
  bool _cuttingSelected = true;
  bool _trimmingSelected = false;
  bool _othersSelected = false;
  final TextEditingController _othersActionController = TextEditingController();

  // Hidden text controllers that store final data for database sync
  final TextEditingController _kindOfTreeController = TextEditingController();
  final TextEditingController _numberOfTreesController =
      TextEditingController();
  final TextEditingController _reasonForRequestController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Restructured Location Detail Parameters
  double? _treeLatitude;
  double? _treeLongitude;
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _fullAddressController = TextEditingController();

  // Menu Dropdown Datasets (Reduces Manual Keyboard Inputs)
  final List<String> _commonTreeVariants = [
    'Mahogany',
    'Mango (Mangifera indica)',
    'Gmelina',
    'Acacia',
    'Narra',
    'Ipil-Ipil',
    'Coconut',
    'Others (Specify Variant Name)',
  ];

  final List<String> _commonReasons = [
    'Poses structural hazard to house / property',
    'Interference with electric powerlines / utilities',
    'Tree is diseased, dead, or decaying',
    'Obstructing authorized road/infrastructure construction',
    'Agricultural clearing / personal land re-development',
    'Others (Provide manual reason)',
  ];

  // Dropdown Component Selection State Variables
  String? _selectedTreeSpecies;
  String? _selectedTreeCountRange;
  String? _selectedReasonContext;
  String? _targetAuthority;
  String? _locationTypeSelected;

  // Visibility Flags for Fallback Input Fields
  bool _showCustomTreeInput = false;
  bool _showCustomCountInput = false;
  bool _showCustomReasonInput = false;

  int _currentStep = 0;

  // Cloudinary Remote Asset Links
  String? _requestLetterUrl;
  String? _lguBarangayCertificationUrl;
  String? _landTitleUrl;
  final List<String> _treePhotographsUrls = <String>[];
  final List<String> _treeContextPhotographsUrls = <String>[];
  String? _ptaPresidentCertificationUrl;

  bool _isUploadingAttachment = false;
  bool _legalCertificationChecked = false;

  // 🟢 ADDED: State variable to track final pipeline database writing operations
  bool _isSubmitting = false;

  SpeciesIdentificationResult? _speciesIdentificationResult;

  bool get _isSchoolGrounds =>
      (_locationTypeSelected ?? '').toLowerCase() == 'school grounds';

  final CloudinaryImageService _cloudinary = const CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  @override
  void dispose() {
    _applicantNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _othersActionController.dispose();
    _kindOfTreeController.dispose();
    _numberOfTreesController.dispose();
    _barangayController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _fullAddressController.dispose();
    _reasonForRequestController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _prefillFromAccount(app_auth_provider.AuthProvider auth) {
    final user = auth.user;
    if (user == null) return;
    final dynamicUser = user as dynamic;

    if (_applicantNameController.text.trim().isEmpty) {
      final role = dynamicUser.role as String?;
      String? extractedName;

      if (role == 'organization') {
        extractedName =
            dynamicUser.orgName ?? dynamicUser.companyName as String?;
      } else {
        try {
          final nameDetails = dynamicUser.nameDetails;
          if (nameDetails is Map) {
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
            if (combined.isNotEmpty) extractedName = combined;
          }
        } catch (_) {}
      }

      if (extractedName != null && extractedName.trim().isNotEmpty) {
        _applicantNameController.text = extractedName.trim();
      } else if (user.name.isNotEmpty) {
        _applicantNameController.text = user.name;
      }
    }

    if (_contactNumberController.text.trim().isEmpty) {
      final phone = user.phoneNumber ?? dynamicUser.phone as String?;
      if (phone != null && phone.trim().isNotEmpty) {
        _contactNumberController.text = phone.trim();
      }
    }

    if (_emailController.text.trim().isEmpty && user.email.isNotEmpty) {
      _emailController.text = user.email;
    }

    if (_addressController.text.trim().isEmpty) {
      List<String> addressParts = [];
      try {
        final addressDetails = dynamicUser.addressDetails;
        if (addressDetails is Map) {
          final houseNum = addressDetails['houseNumber'] as String?;
          final sitio = addressDetails['sitioOrSubdivision'] as String?;
          final brgy = addressDetails['barangay'] as String?;
          final city = addressDetails['city'] as String?;

          if (houseNum != null && houseNum.trim().isNotEmpty)
            addressParts.add(houseNum.trim());
          if (sitio != null && sitio.trim().isNotEmpty)
            addressParts.add(sitio.trim());
          if (brgy != null && brgy.trim().isNotEmpty)
            addressParts.add('Brgy. ${brgy.trim()}');
          if (city != null && city.trim().isNotEmpty)
            addressParts.add(city.trim());
        }
      } catch (_) {}

      if (addressParts.isNotEmpty) {
        _addressController.text = addressParts.join(', ');
      } else {
        final fallbackAddress =
            user.completeAddress ?? dynamicUser.location as String?;
        if (fallbackAddress != null)
          _addressController.text = fallbackAddress.trim();
      }
    }
  }

  void _toggleActionType(String type) {
    setState(() {
      if (type == 'cutting') {
        _cuttingSelected = true;
        _trimmingSelected = false;
        _othersSelected = false;
      } else if (type == 'trimming') {
        _cuttingSelected = false;
        _trimmingSelected = true;
        _othersSelected = false;
      } else {
        _cuttingSelected = false;
        _trimmingSelected = false;
        _othersSelected = true;
      }
      if (!_othersSelected) _othersActionController.clear();
    });
  }

  String? _validateActionType() {
    if (!_cuttingSelected && !_trimmingSelected && !_othersSelected) {
      return 'Please select an application action type.';
    }
    if (_othersSelected && _othersActionController.text.trim().isEmpty) {
      return 'Please specify the action type for Others.';
    }
    return null;
  }

  bool _isUrlSet(String? url) => url != null && url.trim().isNotEmpty;

  String _buildCloudinaryFileName({
    required String fieldKey,
    required String? originalName,
  }) {
    final ext = (originalName != null && originalName.contains('.'))
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '';
    return 'tree_cutting_${fieldKey}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  Future<String?> _pickAndUploadSingle({required String fieldKey}) async {
    if (_isUploadingAttachment) return null;

    setState(() => _isUploadingAttachment = true);
    try {
      final source = await showModalBottomSheet<_UploadSource>(
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
                  'Select Asset Source',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _BottomSheetTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take Photo via Camera',
                  onTap: () => Navigator.pop(ctx, _UploadSource.camera),
                ),
                _BottomSheetTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from Gallery',
                  onTap: () => Navigator.pop(ctx, _UploadSource.gallery),
                ),
                _BottomSheetTile(
                  icon: Icons.attach_file_outlined,
                  label: 'Browse Local Documents',
                  onTap: () => Navigator.pop(ctx, _UploadSource.file),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );

      if (!mounted || source == null) return null;

      if (source == _UploadSource.camera || source == _UploadSource.gallery) {
        final picker = ImagePicker();
        final imageSource = source == _UploadSource.camera
            ? ImageSource.camera
            : ImageSource.gallery;
        final picked = await picker.pickImage(
          source: imageSource,
          imageQuality: 80,
          maxWidth: 1600,
        );
        if (picked == null) return null;

        final Uint8List bytes = await picked.readAsBytes();
        final fileName = _buildCloudinaryFileName(
          fieldKey: fieldKey,
          originalName: picked.name,
        );
        return _cloudinary.uploadImage(bytes: bytes, fileName: fileName);
      }

      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null) return null;

      final fileName = _buildCloudinaryFileName(
        fieldKey: fieldKey,
        originalName: picked.name,
      );
      return _cloudinary.uploadRawFile(bytes: bytes, fileName: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _openSpeciesIdentify() async {
    final result = await TreeSpeciesIdentifySheet.show(
      context,
      cloudinary: _cloudinary,
    );
    if (!mounted || result == null) return;

    final suggestion = result.bestMatch;
    if (suggestion == null) return;

    setState(() {
      _speciesIdentificationResult = result;
      _selectedTreeSpecies = suggestion.matchedDropdownLabel;
      _showCustomTreeInput =
          suggestion.matchedDropdownLabel == TreeSpeciesAliases.othersLabel;

      if (_showCustomTreeInput) {
        _kindOfTreeController.text = TreeSpeciesAliases.formatSpeciesLabel(
          scientificName: suggestion.scientificName,
          commonNames: suggestion.commonNames,
        );
      } else {
        _kindOfTreeController.text = suggestion.matchedDropdownLabel;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Species suggestion applied: ${suggestion.displayName}. You can still change it manually.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleUpload(String key) async {
    final url = await _pickAndUploadSingle(fieldKey: key);
    if (url == null) return;

    setState(() {
      switch (key) {
        case 'requestLetter':
          _requestLetterUrl = url;
          break;
        case 'lguBarangay':
          _lguBarangayCertificationUrl = url;
          break;
        case 'landTitle':
          _landTitleUrl = url;
          break;
        case 'treePhotos':
          _treePhotographsUrls.add(url);
          break;
        case 'treeContextPhotos':
          _treeContextPhotographsUrls.add(url);
          break;
        case 'ptaPresident':
          _ptaPresidentCertificationUrl = url;
          break;
      }
    });
  }

  Future<void> _onStepContinue() async {
    if (_currentStep == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_treeLatitude == null || _treeLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please pinpoint target trees on the interactive map.',
            ),
          ),
        );
        return;
      }
      setState(() => _currentStep = 1);
      return;
    }

    if (_currentStep == 1) {
      if (_targetAuthority == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select your Application Route Destination Authority.',
            ),
          ),
        );
        return;
      }
      if (!_isUrlSet(_requestLetterUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your official Request Letter.'),
          ),
        );
        return;
      }
      if (!_isUrlSet(_lguBarangayCertificationUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please attach your LGU/Barangay Certification (No Objection).',
            ),
          ),
        );
        return;
      }
      if (_treePhotographsUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please upload actual field photographs of the trees.',
            ),
          ),
        );
        return;
      }
      if (_isSchoolGrounds && !_isUrlSet(_ptaPresidentCertificationUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'School Grounds location parameter requires PTA President Certification.',
            ),
          ),
        );
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    if (_currentStep == 2) {
      if (!_legalCertificationChecked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign off on the accountability declaration.'),
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication session expired. Please sign in again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 🟢 FIXED: Wrapped database insertion in a comprehensive state controller & try-catch loop
      setState(() => _isSubmitting = true);

      try {
        final docRef = FirebaseFirestore.instance
            .collection('tree_cutting_permits')
            .doc();

        await docRef.set({
          'applicationType': _cuttingSelected
              ? 'cutting'
              : _trimmingSelected
              ? 'trimming'
              : 'others',
          'othersAction': _othersSelected
              ? _othersActionController.text.trim()
              : null,
          'targetAuthority': _targetAuthority,
          'applicantName': _applicantNameController.text.trim(),
          'email': _emailController.text.trim(),
          'contactNumber': _contactNumberController.text.trim(),
          'address': _addressController.text.trim(),
          'kindOfTree': _kindOfTreeController.text.trim(),
          'numberOfTrees': int.tryParse(_numberOfTreesController.text.trim()),
          'barangay': _barangayController.text.trim(),
          'street': _streetController.text.trim(),
          'landmark': _landmarkController.text.trim(),
          'completeAddressDetails': _fullAddressController.text.trim(),
          'treeLatitude': _treeLatitude,
          'treeLongitude': _treeLongitude,
          'ptaRequirementBasis': _locationTypeSelected,
          'reasonForRequest': _reasonForRequestController.text.trim(),
          'remarks': _remarksController.text.trim(),
          'uploadedPaths': {
            'letterOfRequestPath': _requestLetterUrl,
            'barangayClearancePath': _lguBarangayCertificationUrl,
            'treePicturesPaths': _treePhotographsUrls,
            'treeContextPicturesPaths': _treeContextPhotographsUrls,
            'landTitlePath': _landTitleUrl,
            'ptaPresidentCertificationPath': _ptaPresidentCertificationUrl,
          },
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
          'submittedByUid': user.uid,

          // Initialize the historical tracking tracking array
          //  CORRECTED CODE
          'statusHistory': [
            {
              'status': 'pending',
              'message':
                  'Permit application has been successfully submitted and is awaiting review.',
              'updatedAt': Timestamp.now(), //  Changed to Timestamp.now()
            },
          ],
          if (_speciesIdentificationResult != null)
            'speciesIdentification': _speciesIdentificationResult!.toFirestore(
              userAccepted: true,
            ),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application filed securely into MENRO Baliwag audit pipeline.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        // Captures network disconnects, permission errors, and missing schema validation rule exceptions
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth_provider.AuthProvider>();
    _prefillFromAccount(auth);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Tree Cutting / Trimming Permit Form',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: () {
            if (_currentStep > 0 && !_isSubmitting)
              setState(() => _currentStep -= 1);
          },
          controlsBuilder: (context, details) {
            final isLast = _currentStep == 2;
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  ElevatedButton(
                    // 🟢 FIXED: Disables interactions while asynchronous upload operations are live
                    onPressed: (_isUploadingAttachment || _isSubmitting)
                        ? null
                        : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    // 🟢 FIXED: Replaces flat label text with an interactive layout loader while uploading
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLast
                                ? 'Submit Application'
                                : 'Continue to Next Step',
                          ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _isSubmitting ? null : details.onStepCancel,
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // STEP 1: IDENTITY & GEOGRAPHICAL METRICS MAPPER
            Step(
              title: const Text(
                'Section A - Identity & Parameter Details',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionSubHeader(
                      icon: Icons.person_outline,
                      title: 'Personal Credentials',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _applicantNameController,
                      decoration: const InputDecoration(
                        labelText: 'Applicant Complete Profile Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Permanent Residential Address Residence',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const _SectionSubHeader(
                      icon: Icons.assignment_outlined,
                      title: 'Scope Selection Parameter',
                    ),
                    FormField<void>(
                      validator: (_) => _validateActionType(),
                      builder: (state) => Column(
                        children: [
                          CheckboxListTile(
                            value: _cuttingSelected,
                            activeColor: AppColors.primary,
                            title: const Text(
                              'Tree Cutting Permit Scheme',
                              style: TextStyle(fontSize: 14),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: _isSubmitting
                                ? null
                                : (_) => _toggleActionType('cutting'),
                          ),
                          CheckboxListTile(
                            value: _trimmingSelected,
                            activeColor: AppColors.primary,
                            title: const Text(
                              'Tree Trimming / Systematic Pruning',
                              style: TextStyle(fontSize: 14),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: _isSubmitting
                                ? null
                                : (_) => _toggleActionType('trimming'),
                          ),
                          CheckboxListTile(
                            value: _othersSelected,
                            activeColor: AppColors.primary,
                            title: const Text(
                              'Other Industrial Operations Context',
                              style: TextStyle(fontSize: 14),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: _isSubmitting
                                ? null
                                : (_) => _toggleActionType('others'),
                          ),
                          if (_othersSelected) ...[
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _othersActionController,
                              enabled: !_isSubmitting,
                              decoration: const InputDecoration(
                                labelText: 'Specify operations background...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (state.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 14),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  state.errorText!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const _SectionSubHeader(
                      icon: Icons.nature_outlined,
                      title: 'Tree Matrix (Typing Minimized)',
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _openSpeciesIdentify,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Identify with camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                    if (_speciesIdentificationResult?.bestMatch != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'AI suggestion: ${_speciesIdentificationResult!.bestMatch!.displayName} '
                          '(${_speciesIdentificationResult!.bestMatch!.confidencePercent}% confidence)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: _selectedTreeSpecies,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tree Species Variant',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: _commonTreeVariants
                          .map(
                            (val) => DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (v) => setState(() {
                              _selectedTreeSpecies = v;
                              _showCustomTreeInput =
                                  v == 'Others (Specify Variant Name)';
                              if (!_showCustomTreeInput) {
                                _kindOfTreeController.text = v ?? '';
                              }
                            }),
                      validator: (v) => v == null ? 'Species mandatory' : null,
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: _selectedTreeCountRange,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quantity Scale',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: ['1', '2', '3', '4', '5', 'More than 5']
                          .map(
                            (val) => DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (v) => setState(() {
                              _selectedTreeCountRange = v;
                              _showCustomCountInput = v == 'More than 5';
                              if (!_showCustomCountInput)
                                _numberOfTreesController.text = v ?? '';
                            }),
                      validator: (v) => v == null ? 'Required' : null,
                    ),

                    if (_showCustomTreeInput) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _kindOfTreeController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Provide manual species descriptor...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter descriptor'
                            : null,
                      ),
                    ],
                    if (_showCustomCountInput) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _numberOfTreesController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Enter precise count scale',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: (v) =>
                            v == null || int.tryParse(v.trim()) == null
                            ? 'Must be a number'
                            : null,
                      ),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Operational Request Justification Reason:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Learn more about required justification',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TreeCuttingJustificationGuidelinesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedReasonContext,
                      decoration: const InputDecoration(
                        labelText: 'Operational Request Justification Reason',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      isExpanded: true,
                      items: _commonReasons
                          .map(
                            (val) => DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (v) => setState(() {
                              _selectedReasonContext = v;
                              _showCustomReasonInput =
                                  v == 'Others (Provide manual reason)';
                              if (!_showCustomReasonInput)
                                _reasonForRequestController.text = v ?? '';
                            }),
                      validator: (v) =>
                          v == null ? 'Reason parameter mandatory' : null,
                    ),
                    if (_showCustomReasonInput) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _reasonForRequestController,
                        maxLines: 2,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText:
                              'Describe customized request context summary...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Justification text mandatory'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 2,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText:
                            'Remarks (Official Inspection Field Notes Section)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: _SectionSubHeader(
                            icon: Icons.location_on_outlined,
                            title: 'Location Coordinate Matrix',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.map, color: AppColors.primary),
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  final result =
                                      await Navigator.push<
                                        Map<String, dynamic>
                                      >(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReportLocationPickerScreen(
                                                initialLat: _treeLatitude,
                                                initialLng: _treeLongitude,
                                              ),
                                        ),
                                      );
                                  if (result == null) return;
                                  setState(() {
                                    _treeLatitude = result['lat'] as double?;
                                    _treeLongitude = result['lng'] as double?;
                                    _fullAddressController.text =
                                        result['address'] as String? ?? '';
                                    _barangayController.text =
                                        result['barangay'] as String? ?? '';
                                    _streetController.text =
                                        result['street'] as String? ?? '';
                                    _landmarkController.text =
                                        result['landmark'] as String? ?? '';
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barangayController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Barangay',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _streetController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Street Name',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
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
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fullAddressController,
                      readOnly: true,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Complete Full Address Map String',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _locationTypeSelected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'PTA Requirement Site Classification',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'school grounds',
                          child: Text(
                            'School Grounds Infrastructure',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'not school grounds',
                          child: Text(
                            'Private / General Commercial Property',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (v) => setState(() => _locationTypeSelected = v),
                      validator: (v) =>
                          v == null ? 'Site classification mandatory' : null,
                    ),
                  ],
                ),
              ),
            ),

            // STEP 2: DOCUMENTS UPLOAD ENGINES GATEWAY
            Step(
              title: const Text(
                'Section B - Compliance Upload Route Routing',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Your Intended Request Recipient Authority:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _targetAuthority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'lgu',
                          child: Text(
                            'LGU: Hon. Sonia Viceo-Estrella (Replacements: 20 Seedlings)',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'denr_cenro',
                          child: Text(
                            'DENR-CENRO: Mr. Dennis P. Vergara (Replacements: 50 Seedlings)',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (v) => setState(() => _targetAuthority = v),
                    ),
                    const SizedBox(height: 20),

                    _DocumentUploadTile(
                      label:
                          '1. Addressed Request Letter Document (Must sync directly with target designation field above)',
                      fileSelected: _isUrlSet(_requestLetterUrl),
                      onTap: _isSubmitting
                          ? () {}
                          : () => _handleUpload('requestLetter'),
                      onClear: () => setState(() => _requestLetterUrl = null),
                    ),
                    const SizedBox(height: 12),
                    _DocumentUploadTile(
                      label:
                          '2. Certification from Local Government Unit (No Objection - Barangay / Mayor)',
                      fileSelected: _isUrlSet(_lguBarangayCertificationUrl),
                      onTap: _isSubmitting
                          ? () {}
                          : () => _handleUpload('lguBarangay'),
                      onClear: () =>
                          setState(() => _lguBarangayCertificationUrl = null),
                    ),
                    const SizedBox(height: 12),
                    _DocumentUploadTile(
                      label:
                          '3. Xeroxed Copy of Land Title (Secure and upload if property is private land)',
                      fileSelected: _isUrlSet(_landTitleUrl),
                      onTap: _isSubmitting
                          ? () {}
                          : () => _handleUpload('landTitle'),
                      onClear: () => setState(() => _landTitleUrl = null),
                    ),
                    const SizedBox(height: 12),
                    _DocumentUploadTile(
                      label:
                          '4. Physical Tree Target Photographs (${_treePhotographsUrls.length} Files Configured)',
                      fileSelected: _treePhotographsUrls.isNotEmpty,
                      onTap: _isSubmitting
                          ? () {}
                          : () => _handleUpload('treePhotos'),
                      onClear: () =>
                          setState(() => _treePhotographsUrls.clear()),
                    ),
                    const SizedBox(height: 12),
                    _DocumentUploadTile(
                      label:
                          '5. Context / Before & Surroundings Photos (${_treeContextPhotographsUrls.length} Files Configured)',
                      fileSelected: _treeContextPhotographsUrls.isNotEmpty,
                      onTap: _isSubmitting
                          ? () {}
                          : () => _handleUpload('treeContextPhotos'),
                      onClear: () =>
                          setState(() => _treeContextPhotographsUrls.clear()),
                    ),
                    if (_isSchoolGrounds) ...[
                      const SizedBox(height: 12),
                      _DocumentUploadTile(
                        label:
                            '5. Compulsory Certification from the PTA President of school concerned',
                        fileSelected: _isUrlSet(_ptaPresidentCertificationUrl),
                        onTap: _isSubmitting
                            ? () {}
                            : () => _handleUpload('ptaPresident'),
                        onClear: () => setState(
                          () => _ptaPresidentCertificationUrl = null,
                        ),
                      ),
                    ],
                    if (_isUploadingAttachment) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),

            // STEP 3: ACCOUNTABILITY COMPLIANCE SIGN-OFF
            Step(
              title: const Text(
                'Section C - Legal Sign-off Verification pipeline',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              isActive: _currentStep >= 2,
              state: StepState.editing,
              content: _SectionCard(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Text(
                        'I HEREBY CERTIFY that all information, environmental metrics, and uploaded files provided are completely valid and true.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _legalCertificationChecked,
                      activeColor: AppColors.primary,
                      enabled: !_isSubmitting,
                      title: const Text(
                        'I express full consensus regarding verification specifications validated above.',
                        style: TextStyle(fontSize: 13),
                      ),
                      onChanged: (v) => setState(
                        () => _legalCertificationChecked = v ?? false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REUSABLE REFACTORED ATOMIC COMPONENT DESIGN LANGUAGE ─────────────────

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

class _SectionSubHeader extends StatelessWidget {
  const _SectionSubHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

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
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.label,
    required this.fileSelected,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final bool fileSelected;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: fileSelected
                ? Colors.green.withOpacity(0.04)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fileSelected
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.shade200,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    fileSelected
                        ? Icons.check_circle
                        : Icons.cloud_upload_outlined,
                    color: fileSelected ? Colors.green : AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileSelected
                          ? 'Asset Successfully Linked & Uploaded'
                          : 'Tap to attach verify asset file',
                      style: TextStyle(
                        fontSize: 12,
                        color: fileSelected
                            ? Colors.green.shade800
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                  if (fileSelected)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle,
                        color: Colors.grey,
                        size: 18,
                      ),
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
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
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 16,
        color: AppColors.textGrey,
      ),
      onTap: onTap,
    );
  }
}
