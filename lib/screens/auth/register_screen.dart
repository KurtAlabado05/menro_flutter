import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../../core/constants/app_colors.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../../services/cloudinary_image_service.dart';

enum UserRole { citizen, organization }

// --- STATIC LOCATION DATA ---
// Expand this map as your app scales to new regions.
const Map<String, Map<String, List<String>>> staticLocationData = {
  'Bulacan': {
    'Baliwag': [
      'Bagong Nayon',
      'Barangka',
      'Calantipay',
      'Catulinan',
      'Concepcion',
      'Hinukay',
      'Makinabang',
      'Matangtubig',
      'Pagala',
      'Paitan',
      'Piel',
      'Pinagbarilan',
      'Poblacion',
      'Sabang',
      'San Jose',
      'San Roque',
      'Santa Barbara',
      'Santo Cristo',
      'Santo Niño',
      'Subic',
      'Sulivan',
      'Tangos',
      'Tarcan',
      'Tiaong',
      'Tibag',
      'Virgen delas Flores',
    ],
    'Bocaue': [
      'Antipona',
      'Bagumbayan',
      'Bambang',
      'Batia',
      'Biñang 1st',
      'Biñang 2nd',
      'Bolacan',
      'Bunducan',
      'Bunlo',
      'Caingin',
      'Duhat',
      'Igulot',
      'Lolomboy',
      'Poblacion',
      'Sulucan',
      'Taal',
      'Tambobong',
      'Turo',
      'Wakas',
    ],
    'Malolos': [
      'Anilao',
      'Atlag',
      'Babatnin',
      'Bagna',
      'Bagong Bayan',
      'Balayong',
      'Balite',
      'Bangkalingan',
      'Barihan',
      'Bulihan',
      'Bungahan',
      'Caingin',
    ],
  },
  'Pampanga': {
    'Candaba': [
      'Bahay Pare',
      'Bambang',
      'Barit',
      'Buas',
      'Cuayang Bugtong',
      'Dalayap',
      'Dulong Ilog',
      'Gulap',
      'Lanang',
      'Lourdes',
      'Magumbali',
      'Mandasig',
      'Mandili',
      'Mangga',
      'Mapaniqui',
      'Paligui',
      'Pangclara',
      'Pansinao',
      'Paralaya',
      'Pasig',
      'Pescadores',
      'Pulong Gubat',
      'Pulong Palazan',
      'Salapungan',
      'San Agustin',
      'Santo Rosario',
      'Tagalog',
      'Tenejero',
      'Visal San Pablo',
      'Visal Santo Cristo',
    ],
    'San Fernando': [
      'Alasas',
      'Baliti',
      'Bulaon',
      'Calulut',
      'Dela Paz Norte',
      'Dela Paz Sur',
      'Dolores',
      'Juliana',
      'Lara',
      'Lourdes',
      'Magliman',
      'Maimpis',
      'Malino',
    ],
  },
  'Metro Manila': {
    'Quezon City': [
      'Alicia',
      'Amihan',
      'Apolonio Samson',
      'Bagbag',
      'Bagumbayan',
      'Bagumbuhay',
      'Bahay Toro',
      'Balingasa',
      'Balong Bato',
      'Batasan Hills',
    ],
    'Manila': [
      'Binondo',
      'Ermita',
      'Intramuros',
      'Malate',
      'Paco',
      'Pandacan',
      'Port Area',
      'Quiapo',
      'Sampaloc',
      'San Miguel',
      'San Nicolas',
      'Santa Ana',
      'Santa Cruz',
      'Tondo',
    ],
  },
};

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

  // View lists for dropdowns
  List<String> _provinces = [];
  List<String> _cities = [];
  List<String> _barangays = [];

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

  @override
  void initState() {
    super.initState();
    // Initialize provinces instantly from the hardcoded map
    _provinces = staticLocationData.keys.toList();
    _provinces.sort(); // Optional: Keep them alphabetical
  }

  // Cascading Location Logic
  void _updateCitiesList(String province) {
    setState(() {
      _cities = staticLocationData[province]?.keys.toList() ?? [];
      _cities.sort();
    });
  }

  void _updateBarangaysList(String province, String city) {
    setState(() {
      _barangays = staticLocationData[province]?[city] ?? [];
      _barangays.sort();
    });
  }

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

  UserRole _selectedRole = UserRole.citizen;
  bool _isLoading = false;

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '####-###-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  void _clearFields() {
    _firstNameController.clear();
    _middleNameController.clear();
    _lastNameController.clear();
    _orgNameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmController.clear();
    _contactPersonController.clear();
    _businessPermitController.clear();
    _phoneNumberController.clear();
    _phoneMaskFormatter.clear();
    _houseNumController.clear();
    _sitioController.clear();
    setState(() {
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities = [];
      _barangays = [];
    });
  }

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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your Barangay")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      final String finalDisplayName = _selectedRole == UserRole.citizen
          ? "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}"
          : _orgNameController.text.trim();

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.sendEmailVerification();
      await userCredential.user?.updateDisplayName(finalDisplayName);

      Map<String, dynamic> userData = {
        'uid': userCredential.user!.uid,
        'role': _selectedRole.name,
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

      if (_selectedRole == UserRole.citizen) {
        userData['nameDetails'] = {
          'firstName': _firstNameController.text.trim(),
          'middleName': _middleNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
        };

        if (_citizenNationalIdBytes == null ||
            _citizenNationalIdFileName == null) {
          throw Exception('Citizen National ID is required');
        }

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

        if (_organizationPermitBytes == null ||
            _organizationPermitFileName == null) {
          throw Exception('Organization Business Permit document is required');
        }

        final String? permitUrl = await _uploadFileToCloudinary(
          bytes: _organizationPermitBytes,
          fileName: _organizationPermitFileName,
        );

        if (permitUrl == null || permitUrl.isEmpty) {
          throw Exception('Failed to upload Organization Business Permit');
        }

        userData['organizationPermitUrl'] = permitUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful! Verify your email link."),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication failed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
    _phoneNumberController.dispose();
    _houseNumController.dispose();
    _sitioController.dispose();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create an Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment<UserRole>(
                              value: UserRole.citizen,
                              label: Text('Citizen'),
                              icon: Icon(Icons.person_outline),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.organization,
                              label: Text('Organization'),
                              icon: Icon(Icons.business_outlined),
                            ),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (Set<UserRole> newSelection) {
                            setState(() {
                              _selectedRole = newSelection.first;
                              _clearFields();
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // --- IDENTITY SECTION ---
                        if (_selectedRole == UserRole.citizen) ...[
                          CustomTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            prefixIcon: Icons.badge_outlined,
                            validator: (val) =>
                                val!.trim().isEmpty ? 'Required field' : null,
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
                            validator: (val) =>
                                val!.trim().isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: _isCitizenDocReady
                                ? 'National ID Selected'
                                : 'Pick Citizen National ID',
                            onPressed: _pickCitizenNationalId,
                          ),
                          if (_citizenNationalIdFileName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'File: ${_citizenNationalIdFileName!}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ] else ...[
                          CustomTextField(
                            controller: _orgNameController,
                            label: 'Organization / Business Name',
                            prefixIcon: Icons.business,
                            validator: (val) =>
                                val!.trim().isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _contactPersonController,
                            label: 'Authorized Contact Person',
                            prefixIcon: Icons.person_outline,
                            validator: (val) =>
                                val!.trim().isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _businessPermitController,
                            label: 'Business / Mayor\'s Permit Number',
                            prefixIcon: Icons.gavel_outlined,
                            validator: (val) =>
                                val!.trim().isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: _isOrganizationDocReady
                                ? 'Business Permit Document Selected'
                                : 'Pick Organization Business Permit',
                            onPressed: _pickOrganizationPermit,
                          ),
                          if (_organizationPermitFileName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'File: ${_organizationPermitFileName!}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],

                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number (e.g. 0917-123-4567)',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_phoneMaskFormatter],
                          validator: (val) {
                            if (val == null || val.isEmpty)
                              return 'Required field';
                            if (val.length < 13)
                              return 'Enter a complete 11-digit mobile number';
                            if (!val.startsWith('09'))
                              return 'Must be a valid PH mobile number starting with 09';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // --- STRUCTURED ADDRESS SEGMENT ---
                        const Text(
                          'Address Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _houseNumController,
                                label: 'Bldg / House No.',
                                prefixIcon: Icons.tag,
                                validator: (val) =>
                                    val!.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _sitioController,
                                label: 'Sitio / Street',
                                prefixIcon: Icons.add_road,
                                validator: (val) =>
                                    val!.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // --- LOCATION DROPDOWNS ---
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedProvince,
                                decoration: const InputDecoration(
                                  labelText: 'Province',
                                ),
                                items: _provinces
                                    .map(
                                      (String p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedProvince = val;
                                    _selectedCity = null;
                                    _selectedBarangay = null;
                                    _cities = [];
                                    _barangays = [];
                                  });
                                  if (val != null) _updateCitiesList(val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCity,
                                decoration: const InputDecoration(
                                  labelText: 'City/Municipality',
                                ),
                                items: _cities
                                    .map(
                                      (String c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCity = val;
                                    _selectedBarangay = null;
                                    _barangays = [];
                                  });
                                  if (val != null &&
                                      _selectedProvince != null) {
                                    _updateBarangaysList(
                                      _selectedProvince!,
                                      val,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedBarangay,
                          decoration: const InputDecoration(
                            labelText: 'Barangay',
                          ),
                          items: _barangays
                              .map(
                                (String b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedBarangay = val),
                        ),
                        const SizedBox(height: 24),

                        // --- CORE AUTH CREDENTIALS ---
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => !val!.contains('@')
                              ? 'Enter a valid email address'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          validator: (val) => val!.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmController,
                          label: 'Confirm Password',
                          prefixIcon: Icons.lock_reset_outlined,
                          isPassword: true,
                          validator: (val) => val != _passwordController.text
                              ? 'Passwords match conflict'
                              : null,
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: 'Register',
                          onPressed: _handleRegister,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
