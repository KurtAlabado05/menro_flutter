
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/constants/static_location_data.dart';
import '../../models/account_type.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_image_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_widgets.dart';
import '../../widgets/skeleton_loader.dart';
import 'widgets/edit_profile_sections.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const CloudinaryImageService _cloudinary = CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;
  bool _dirty = false;
  bool _hasOrganizationApplication = false;
  AccountType? _accountType = AccountType.citizen;
  String _userRole = 'citizen';
  String _emailAddress = '';

  String? _province;
  String? _city;
  String? _barangay;

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseController = TextEditingController();
  final _sitioController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _businessPermitController = TextEditingController();

  Uint8List? _newDocBytes;
  String? _newDocFileName;
  String? _existingDocUrl;

  final _phoneMask = MaskTextInputFormatter(
    mask: '####-###-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _orgNameController.dispose();
    _phoneController.dispose();
    _houseController.dispose();
    _sitioController.dispose();
    _contactPersonController.dispose();
    _businessPermitController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      _userRole = data['role']?.toString() ?? 'citizen';
      _accountType = AccountType.fromStoredValue(
        data['accountType'] ?? data['role'],
      );
      _hasOrganizationApplication =
          (data['organizationId'] as String?)?.isNotEmpty ?? false;
      _emailAddress = data['email']?.toString() ?? user.email ?? '';
      _phoneController.text = data['phoneNumber']?.toString() ?? '';

      final nameDetails = data['nameDetails'] as Map<String, dynamic>? ?? {};
      if (_accountType == AccountType.citizen) {
        _firstNameController.text = nameDetails['firstName'] ?? '';
        _middleNameController.text = nameDetails['middleName'] ?? '';
        _lastNameController.text = nameDetails['lastName'] ?? '';
        _existingDocUrl = data['citizenNationalIdUrl'];
      } else if (_accountType == AccountType.organization) {
        _orgNameController.text =
            nameDetails['organizationName'] ?? data['name'] ?? '';
        final org = data['organizationDetails'] as Map<String, dynamic>? ?? {};
        _contactPersonController.text = org['contactPerson'] ?? '';
        _businessPermitController.text = org['businessPermitNumber'] ?? '';
        _existingDocUrl =
            data['organizationPermitUrl'] ?? data['businessPermitUrl'];
      }

      final address = data['addressDetails'] as Map<String, dynamic>? ?? {};
      _houseController.text = address['houseNumber'] ?? '';
      _sitioController.text = address['sitioOrSubdivision'] ?? '';

      final savedProvince = address['province'] as String?;
      final savedCity = address['city'] as String?;
      final savedBarangay = address['barangay'] as String?;
      if (citiesForProvince(savedProvince).isNotEmpty) {
        _province = savedProvince;
        if (citiesForProvince(savedProvince).contains(savedCity)) {
          _city = savedCity;
          if (barangaysForCity(savedProvince, savedCity)
              .contains(savedBarangay)) {
            _barangay = savedBarangay;
          }
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _pickNewDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null || !mounted) return;
    setState(() {
      _newDocBytes = file.bytes;
      _newDocFileName = file.name;
      _dirty = true;
    });
  }

  Future<String> _uploadNewDocument(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    final isImage =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    return isImage
        ? _cloudinary.uploadImage(bytes: bytes, fileName: fileName)
        : _cloudinary.uploadRawFile(bytes: bytes, fileName: fileName);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      showAppSnackBar(
        context,
        'Please fix the highlighted fields.',
        type: AppMessageType.warning,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      var docUrl = _existingDocUrl;
      if (_newDocBytes != null && _newDocFileName != null) {
        docUrl = await _uploadNewDocument(_newDocBytes!, _newDocFileName!);
      }

      final houseNo = _houseController.text.trim();
      final sitio = _sitioController.text.trim();
      final update = <String, dynamic>{
        if (_accountType != null) 'accountType': _accountType!.name,
        'phoneNumber': _phoneController.text.trim(),
        'completeAddress': '$houseNo, $sitio, $_barangay, $_city, $_province',
        'addressDetails': {
          'houseNumber': houseNo,
          'sitioOrSubdivision': sitio,
          'barangay': _barangay,
          'city': _city,
          'province': _province,
        },
      };

      String? displayName;
      if (_accountType == AccountType.citizen) {
        displayName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        update['name'] = displayName;
        update['nameDetails'] = {
          'firstName': _firstNameController.text.trim(),
          'middleName': _middleNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
        };
        update['citizenNationalIdUrl'] = docUrl;
      } else if (_accountType == AccountType.organization &&
          !_hasOrganizationApplication) {
        displayName = _orgNameController.text.trim();
        update['name'] = displayName;
        update['nameDetails'] = {'organizationName': displayName};
        update['organizationDetails'] = {
          'contactPerson': _contactPersonController.text.trim(),
          'businessPermitNumber': _businessPermitController.text.trim(),
        };
        update['organizationPermitUrl'] = docUrl;
      }

      if (displayName != null) await user.updateDisplayName(displayName);
      await _db
          .collection('users')
          .doc(user.uid)
          .set(update, SetOptions(merge: true));

      if (!mounted) return;
      await context.read<AuthProvider>().reloadUser();
      if (!mounted) return;
      _dirty = false;
      showAppSnackBar(
        context,
        'Profile updated.',
        type: AppMessageType.success,
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not save your profile. Check your connection and try again.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final navigator = Navigator.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits have not been saved.'),
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
    if (discard == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Edit Profile')),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const SkeletonList(count: 3);
    if (_loadFailed) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load your profile',
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _loadProfile,
      );
    }

    final isCitizen = _accountType == AccountType.citizen;
    final isOrg = _accountType == AccountType.organization;
    const gap = SizedBox(height: AppSpacing.lg);

    return Form(
      key: _formKey,
      onChanged: () {
        if (!_dirty) setState(() => _dirty = true);
      },
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LockedInfoCard(
                  title: 'Account',
                  rows: [
                    (label: 'Email', value: _emailAddress),
                    (
                      label: 'Account type',
                      value: _accountType?.label ?? _userRole.toUpperCase(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Identity'),
                const SizedBox(height: AppSpacing.sm),
                if (isCitizen) ...[
                  CustomTextField(
                    controller: _firstNameController,
                    label: 'First name',
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    validator: requiredField,
                  ),
                  gap,
                  CustomTextField(
                    controller: _middleNameController,
                    label: 'Middle name (optional)',
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.middleName],
                  ),
                  gap,
                  CustomTextField(
                    controller: _lastNameController,
                    label: 'Last name',
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    validator: requiredField,
                  ),
                  gap,
                  DocumentReplaceTile(
                    buttonLabel: _newDocFileName != null
                        ? 'Choose a different ID'
                        : 'Replace valid ID',
                    savedMessage: 'Your ID is saved securely.',
                    hasExisting: _existingDocUrl != null,
                    stagedFileName: _newDocFileName,
                    onPick: _pickNewDocument,
                  ),
                ] else if (isOrg && _hasOrganizationApplication)
                  LockedInfoCard(
                    title: 'Organization',
                    rows: [
                      (
                        label: 'Legal name',
                        value: _orgNameController.text,
                      ),
                      (
                        label: 'Representative',
                        value: _contactPersonController.text,
                      ),
                      (
                        label: 'Permit no.',
                        value: _businessPermitController.text,
                      ),
                    ],
                    footnote: _existingDocUrl != null
                        ? 'Permit submitted for organization review'
                        : null,
                  )
                else if (isOrg) ...[
                  CustomTextField(
                    controller: _orgNameController,
                    label: 'Organization / business name',
                    prefixIcon: Icons.business,
                    textInputAction: TextInputAction.next,
                    validator: requiredField,
                  ),
                  gap,
                  CustomTextField(
                    controller: _contactPersonController,
                    label: 'Authorized contact person',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: requiredField,
                  ),
                  gap,
                  CustomTextField(
                    controller: _businessPermitController,
                    label: "Business / Mayor's permit number",
                    prefixIcon: Icons.gavel_outlined,
                    textInputAction: TextInputAction.next,
                    validator: requiredField,
                  ),
                  gap,
                  DocumentReplaceTile(
                    buttonLabel: _newDocFileName != null
                        ? 'Choose a different permit'
                        : 'Update business permit',
                    savedMessage: 'Your permit is saved on the server.',
                    hasExisting: _existingDocUrl != null,
                    stagedFileName: _newDocFileName,
                    onPick: _pickNewDocument,
                  ),
                ],
                gap,
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone number (e.g. 0917-123-4567)',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [_phoneMask],
                  validator: phoneValidator,
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Address'),
                const SizedBox(height: AppSpacing.sm),
                AddressFields(
                  houseController: _houseController,
                  sitioController: _sitioController,
                  province: _province,
                  city: _city,
                  barangay: _barangay,
                  onProvinceChanged: (v) => setState(() {
                    _province = v;
                    _city = null;
                    _barangay = null;
                  }),
                  onCityChanged: (v) => setState(() {
                    _city = v;
                    _barangay = null;
                  }),
                  onBarangayChanged: (v) => setState(() => _barangay = v),
                ),
                const SizedBox(height: AppSpacing.xl),
                CustomButton(
                  text: 'Save changes',
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
