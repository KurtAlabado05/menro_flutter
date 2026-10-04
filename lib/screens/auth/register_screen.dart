import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../models/account_type.dart';
import '../../widgets/address_fields.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/app_brand_logos.dart';
import '../../widgets/form_validators.dart';
import '../../services/cloudinary_image_service.dart';
import '../../services/organization_registration_service.dart';
import '../profile/organization_application_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Location States
  String? _selectedBarangay;
  String? _selectedCity;
  String? _selectedProvince;

  // 1. Name Sub-Fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();

  // 2. Auth & Contact Fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  // 3. Modular Address Fields
  final TextEditingController _houseNumController = TextEditingController();
  final TextEditingController _sitioController = TextEditingController();

  // 4. Organization Details
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _businessPermitController =
      TextEditingController();
  final TextEditingController _permitIssuerController = TextEditingController();

  // Upload placeholders
  Uint8List? _citizenNationalIdBytes;
  String? _citizenNationalIdFileName;

  Uint8List? _organizationPermitBytes;
  String? _organizationPermitFileName;

  final CloudinaryImageService _cloudinaryImageService =
      const CloudinaryImageService(
        cloudName: 'dfo5l4d4t',
        uploadPreset: 'flutter_upload_preset',
      );

  bool get _isCitizenDocReady => _citizenNationalIdBytes != null;
  bool get _isOrganizationDocReady => _organizationPermitBytes != null;

  AccountType _selectedAccountType = AccountType.citizen;
  bool _isLoading = false;
  int _currentStep = 0;
  final ScrollController _registrationScrollController = ScrollController();

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '####-###-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  Future<void> _pickCitizenNationalId() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() {
      _citizenNationalIdBytes = file.bytes;
      _citizenNationalIdFileName = file.name;
    });
  }

  Future<void> _pickOrganizationPermit() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() {
      _organizationPermitBytes = file.bytes;
      _organizationPermitFileName = file.name;
    });
  }

  Future<String?> _uploadFileToCloudinary({
    required Uint8List? bytes,
    required String? fileName,
  }) async {
    if (bytes == null || fileName == null) return null;
    final lower = fileName.toLowerCase();
    final isImage =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');

    if (isImage) {
      return _cloudinaryImageService.uploadImage(
        bytes: bytes,
        fileName: fileName,
      );
    }
    return _cloudinaryImageService.uploadRawFile(
      bytes: bytes,
      fileName: fileName,
    );
  }

  void _continueToContactDetails() {
    if (!_formKey.currentState!.validate()) return;

    final hasRequiredDocument = _selectedAccountType == AccountType.citizen
        ? _isCitizenDocReady
        : _isOrganizationDocReady;
    if (!hasRequiredDocument) {
      showAppSnackBar(
        context,
        _selectedAccountType == AccountType.citizen
            ? 'Please add your Citizen National ID to continue.'
            : 'Please add the Organization Business Permit to continue.',
        type: AppMessageType.warning,
      );
      return;
    }

    setState(() => _currentStep = 1);
    _registrationScrollController.jumpTo(0);
  }

  void _backToAccountDetails() {
    setState(() => _currentStep = 0);
    _registrationScrollController.jumpTo(0);
  }

  Widget _buildDocumentPicker({
    required String buttonLabel,
    required String? fileName,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: fileName == null ? buttonLabel : 'Replace document',
          button: true,
          enabled: true,
          onTap: onPick,
          child: CustomButton(
            text: fileName == null ? buttonLabel : 'Replace document',
            icon: fileName == null ? Icons.upload_file_outlined : Icons.refresh,
            onPressed: onPick,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Accepted formats: JPG, PNG, or PDF.',
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        if (fileName != null) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Selected file: $fileName',
            container: true,
            child: Row(
              children: [
                const Icon(Icons.attach_file, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label: 'Remove document',
                  button: true,
                  enabled: true,
                  onTap: onRemove,
                  child: IconButton(
                    tooltip: 'Remove document',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildAccountDetailsStep() {
    return [
      Semantics(
        label: 'Account type selection',
        container: true,
        child: SegmentedButton<AccountType>(
          segments: [
            ButtonSegment<AccountType>(
              value: AccountType.citizen,
              label: const Text('Citizen'),
              icon: const Icon(Icons.person_outline),
            ),
            ButtonSegment<AccountType>(
              value: AccountType.organization,
              label: const Text('Organization'),
              icon: const Icon(Icons.business_outlined),
            ),
          ],
          selected: {_selectedAccountType},
          onSelectionChanged: (selection) {
            setState(() => _selectedAccountType = selection.first);
          },
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _selectedAccountType == AccountType.citizen
            ? 'For individual residents. A National ID is needed to verify your account.'
            : 'For registered organizations. MENRO reviews the business permit before organization access is approved.',
        style: const TextStyle(color: AppColors.textGrey, height: 1.4),
      ),
      const SizedBox(height: 24),
      if (_selectedAccountType == AccountType.citizen) ...[
        CustomTextField(
          controller: _firstNameController,
          label: 'First Name',
          prefixIcon: Icons.badge_outlined,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter your first name'
              : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _middleNameController,
          label: 'Middle Name (Optional)',
          prefixIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _lastNameController,
          label: 'Last Name',
          prefixIcon: Icons.badge_outlined,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter your last name'
              : null,
        ),
        const SizedBox(height: 16),
        _buildDocumentPicker(
          buttonLabel: 'Upload National ID',
          fileName: _citizenNationalIdFileName,
          onPick: _pickCitizenNationalId,
          onRemove: () => setState(() {
            _citizenNationalIdBytes = null;
            _citizenNationalIdFileName = null;
          }),
        ),
      ] else ...[
        CustomTextField(
          controller: _orgNameController,
          label: 'Organization / Business Name',
          prefixIcon: Icons.business,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the legal organization name'
              : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _contactPersonController,
          label: 'Authorized Contact Person',
          prefixIcon: Icons.person_outline,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the authorized contact person'
              : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _businessPermitController,
          label: 'Business / Mayor\'s Permit Number',
          prefixIcon: Icons.gavel_outlined,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the permit number'
              : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _permitIssuerController,
          label: 'Permit Issuing Authority',
          prefixIcon: Icons.account_balance_outlined,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the permit issuing authority'
              : null,
        ),
        const SizedBox(height: 16),
        _buildDocumentPicker(
          buttonLabel: 'Upload business permit',
          fileName: _organizationPermitFileName,
          onPick: _pickOrganizationPermit,
          onRemove: () => setState(() {
            _organizationPermitBytes = null;
            _organizationPermitFileName = null;
          }),
        ),
      ],
    ];
  }

  List<Widget> _buildContactDetailsStep() {
    return [
      if (_selectedAccountType == AccountType.organization) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your application will be reviewed by MENRO. Organization features become available after approval.',
                  style: TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      CustomTextField(
        controller: _phoneNumberController,
        label: 'Phone Number (e.g. 0917-123-4567)',
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        inputFormatters: [_phoneMaskFormatter],
        validator: phoneValidator,
      ),
      const SizedBox(height: 24),
      const Text(
        'Address Details',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      AddressFields(
        houseController: _houseNumController,
        sitioController: _sitioController,
        province: _selectedProvince,
        city: _selectedCity,
        barangay: _selectedBarangay,
        onProvinceChanged: (value) => setState(() {
          _selectedProvince = value;
          _selectedCity = null;
          _selectedBarangay = null;
        }),
        onCityChanged: (value) => setState(() {
          _selectedCity = value;
          _selectedBarangay = null;
        }),
        onBarangayChanged: (value) => setState(() => _selectedBarangay = value),
      ),
      const SizedBox(height: 24),
      CustomTextField(
        controller: _emailController,
        label: 'Email Address',
        prefixIcon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        validator: (value) => value == null || !value.contains('@')
            ? 'Enter a valid email address'
            : null,
      ),
      const SizedBox(height: 16),
      CustomTextField(
        controller: _passwordController,
        label: 'Password',
        prefixIcon: Icons.lock_outline,
        isPassword: true,
        validator: (value) => value == null || value.length < 6
            ? 'Use at least 6 characters'
            : null,
      ),
      const SizedBox(height: 4),
      const Text(
        'Use at least 6 characters.',
        style: TextStyle(fontSize: 13, color: AppColors.textGrey),
      ),
      const SizedBox(height: 16),
      CustomTextField(
        controller: _confirmController,
        label: 'Confirm Password',
        prefixIcon: Icons.lock_reset_outlined,
        isPassword: true,
        validator: (value) =>
            value != _passwordController.text ? 'Passwords do not match' : null,
      ),
    ];
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBarangay == null) {
      showAppSnackBar(
        context,
        'Please select your Barangay',
        type: AppMessageType.warning,
      );
      return;
    }

    final missingCitizenDocument =
        _selectedAccountType == AccountType.citizen &&
        (_citizenNationalIdBytes == null || _citizenNationalIdFileName == null);
    final missingOrganizationDocument =
        _selectedAccountType == AccountType.organization &&
        (_organizationPermitBytes == null ||
            _organizationPermitFileName == null);
    if (missingCitizenDocument || missingOrganizationDocument) {
      showAppSnackBar(
        context,
        missingCitizenDocument
            ? 'Citizen National ID is required.'
            : 'Organization Business Permit document is required.',
        type: AppMessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      final String finalDisplayName =
          _selectedAccountType == AccountType.citizen
          ? "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}"
          : _orgNameController.text.trim();

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.sendEmailVerification();
      await userCredential.user?.updateDisplayName(finalDisplayName);

      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'role': _selectedAccountType.name,
        'accountType': _selectedAccountType.name,
        'name': finalDisplayName,
        'email': email,
        'phoneNumber': _phoneNumberController.text.trim(),
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'addressDetails': {
          'houseNumber': _houseNumController.text.trim(),
          'sitioOrSubdivision': _sitioController.text.trim(),
          'barangay': _selectedBarangay, // Now saving direct string names!
          'city': _selectedCity,
          'province': _selectedProvince,
        },
      };

      if (_selectedAccountType == AccountType.citizen) {
        userData['nameDetails'] = {
          'firstName': _firstNameController.text.trim(),
          'middleName': _middleNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
        };

        final String? nationalIdUrl = await _uploadFileToCloudinary(
          bytes: _citizenNationalIdBytes,
          fileName: _citizenNationalIdFileName,
        );

        if (nationalIdUrl == null || nationalIdUrl.isEmpty) {
          throw Exception('Failed to upload Citizen National ID');
        }

        userData['citizenNationalIdUrl'] = nationalIdUrl;
      } else {
        userData['nameDetails'] = {
          'organizationName': _orgNameController.text.trim(),
        };
        userData['organizationDetails'] = {
          'contactPerson': _contactPersonController.text.trim(),
          'businessPermitNumber': _businessPermitController.text.trim(),
        };

        final String? permitUrl = await _uploadFileToCloudinary(
          bytes: _organizationPermitBytes,
          fileName: _organizationPermitFileName,
        );

        if (permitUrl == null || permitUrl.isEmpty) {
          throw Exception('Failed to upload Organization Business Permit');
        }

        userData['organizationPermitUrl'] = permitUrl;
      }

      if (_selectedAccountType == AccountType.organization) {
        await const OrganizationRegistrationService().submitApplication({
          'legalName': _orgNameController.text.trim(),
          'permitIssuer': _permitIssuerController.text.trim(),
          'permitNumber': _businessPermitController.text.trim(),
          'permitDocumentUrl': userData['organizationPermitUrl'],
          'contactPerson': _contactPersonController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'addressDetails': userData['addressDetails'],
        });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData, SetOptions(merge: true));
      }

      if (mounted) {
        showAppSnackBar(
          context,
          _selectedAccountType == AccountType.organization
              ? 'Organization application submitted. It is pending review; verify your email link.'
              : 'Registration successful! Verify your email link.',
          type: AppMessageType.success,
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use' &&
          _selectedAccountType == AccountType.organization &&
          FirebaseAuth.instance.currentUser?.email?.toLowerCase() ==
              _emailController.text.trim().toLowerCase()) {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OrganizationApplicationScreen(),
            ),
          );
        }
        return;
      }
      final message = e.code == 'email-already-in-use'
          ? 'This email already has an account. Sign in to it, then use Profile > Apply for an organization account.'
          : e.message ?? 'Authentication failed';
      if (mounted) {
        showAppSnackBar(context, message, type: AppMessageType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Error: $e', type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _orgNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _contactPersonController.dispose();
    _businessPermitController.dispose();
    _permitIssuerController.dispose();
    _phoneNumberController.dispose();
    _houseNumController.dispose();
    _sitioController.dispose();
    _registrationScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Center(
                  child: SingleChildScrollView(
                    controller: _registrationScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppBrandLogos()),
                        const SizedBox(height: 20),
                        const Text(
                          'Create an Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Step ${_currentStep + 1} of 2',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _currentStep == 0 ? 0.5 : 1,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceLight,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _currentStep == 0
                              ? 'Account details'
                              : 'Contact and sign-in',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...(_currentStep == 0
                            ? _buildAccountDetailsStep()
                            : _buildContactDetailsStep()),
                        const SizedBox(height: 24),
                        if (_currentStep == 0)
                          CustomButton(
                            text: 'Continue',
                            icon: Icons.arrow_forward,
                            onPressed: _continueToContactDetails,
                          )
                        else ...[
                          CustomButton(
                            text: 'Create Account',
                            icon: Icons.person_add_alt_1,
                            onPressed: _handleRegister,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _backToAccountDetails,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to account details'),
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
}
