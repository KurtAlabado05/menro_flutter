import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../core/constants/app_colors.dart';
import '../../services/cloudinary_image_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

// --- STATIC LOCATION DATA ---
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String _userRole =
      'individual'; // Aligned with 'Screenshot_20260527-234356.jpg' schema
  String _emailAddress = '';

  // Location Hierarchy States
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;

  List<String> _provinces = [];
  List<String> _cities = [];
  List<String> _barangays = [];

  // Text Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _houseNumController = TextEditingController();
  final _sitioController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _businessPermitController = TextEditingController();

  // Document Variables
  Uint8List? _newDocBytes;
  String? _newDocFileName;
  String? _existingDocUrl;

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '####-###-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final CloudinaryImageService _cloudinaryImageService =
      const CloudinaryImageService(
        cloudName: 'dfo5l4d4t',
        uploadPreset: 'flutter_upload_preset',
      );

  @override
  void initState() {
    super.initState();
    _provinces = staticLocationData.keys.toList()..sort();
    _fetchCurrentProfileData();
  }

  Future<void> _fetchCurrentProfileData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      _userRole = data['role'] ?? 'individual';
      _emailAddress = data['email'] ?? '';

      // Set Phone Number directly using database dash formatting format
      _phoneNumberController.text = data['phoneNumber'] ?? '';

      // Extract Name Blocks matching target role
      final nameDetails = data['nameDetails'] as Map<String, dynamic>? ?? {};
      if (_userRole == 'individual') {
        _firstNameController.text = nameDetails['firstName'] ?? '';
        _middleNameController.text = nameDetails['middleName'] ?? '';
        _lastNameController.text = nameDetails['lastName'] ?? '';
        _existingDocUrl = data['citizenNationalIdUrl'];
      } else {
        _orgNameController.text = nameDetails['organizationName'] ?? '';
        final orgDetails =
            data['organizationDetails'] as Map<String, dynamic>? ?? {};
        _contactPersonController.text = orgDetails['contactPerson'] ?? '';
        _businessPermitController.text =
            orgDetails['businessPermitNumber'] ?? '';
        _existingDocUrl = data['organizationPermitUrl'];
      }

      // Address Parsing
      final address = data['addressDetails'] as Map<String, dynamic>? ?? {};
      _houseNumController.text = address['houseNumber'] ?? '';
      _sitioController.text = address['sitioOrSubdivision'] ?? '';

      final savedProvince = address['province'] as String?;
      final savedCity = address['city'] as String?;
      final savedBarangay = address['barangay'] as String?;

      if (savedProvince != null &&
          staticLocationData.containsKey(savedProvince)) {
        _selectedProvince = savedProvince;
        _cities = staticLocationData[savedProvince]!.keys.toList()..sort();

        if (savedCity != null &&
            staticLocationData[savedProvince]!.containsKey(savedCity)) {
          _selectedCity = savedCity;
          _barangays = List<String>.from(
            staticLocationData[savedProvince]![savedCity]!,
          )..sort();

          if (savedBarangay != null && _barangays.contains(savedBarangay)) {
            _selectedBarangay = savedBarangay;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading account data: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

  Future<void> _pickNewDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() {
      _newDocBytes = file.bytes;
      _newDocFileName = file.name;
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

  Future<void> _handleSaveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBarangay == null ||
        _selectedCity == null ||
        _selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete your address details")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user session found');

      String? updatedDocUrl = _existingDocUrl;
      if (_newDocBytes != null && _newDocFileName != null) {
        final cloudUrl = await _uploadFileToCloudinary(
          bytes: _newDocBytes,
          fileName: _newDocFileName,
        );
        if (cloudUrl == null || cloudUrl.isEmpty) {
          throw Exception('Failed to upload new validation documents');
        }
        updatedDocUrl = cloudUrl;
      }

      // Generate completeAddress string format dynamically
      final String houseNo = _houseNumController.text.trim();
      final String sitio = _sitioController.text.trim();
      final String completeAddressString =
          "$houseNo, $sitio, $_selectedBarangay, $_selectedCity, $_selectedProvince";

      Map<String, dynamic> updateData = {
        'phoneNumber': _phoneNumberController.text
            .trim(), // Dash-formatted sync
        'completeAddress': completeAddressString,
        'addressDetails': {
          'houseNumber': houseNo,
          'sitioOrSubdivision': sitio,
          'barangay': _selectedBarangay,
          'city': _selectedCity,
          'province': _selectedProvince,
        },
      };

      String finalDisplayName = '';

      if (_userRole == 'individual') {
        finalDisplayName =
            "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
        updateData['name'] = finalDisplayName;
        updateData['nameDetails'] = {
          'firstName': _firstNameController.text.trim(),
          'middleName': _middleNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
        };
        updateData['citizenNationalIdUrl'] = updatedDocUrl;
      } else {
        finalDisplayName = _orgNameController.text.trim();
        updateData['name'] = finalDisplayName;
        updateData['nameDetails'] = {'organizationName': finalDisplayName};
        updateData['organizationDetails'] = {
          'contactPerson': _contactPersonController.text.trim(),
          'businessPermitNumber': _businessPermitController.text.trim(),
        };
        updateData['organizationPermitUrl'] = updatedDocUrl;
      }

      await user.updateDisplayName(finalDisplayName);
      await _db
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update profile: $e")));
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
    _phoneNumberController.dispose();
    _houseNumController.dispose();
    _sitioController.dispose();
    _contactPersonController.dispose();
    _businessPermitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- READ-ONLY ACCOUNT IDENTIFIERS ---
                      AbsorbPointer(
                        absorbing: true,
                        child: Opacity(
                          opacity: 0.6,
                          child: CustomTextField(
                            controller: TextEditingController(
                              text: _emailAddress,
                            ),
                            label: 'Email Address',
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AbsorbPointer(
                        absorbing: true,
                        child: Opacity(
                          opacity: 0.6,
                          child: CustomTextField(
                            controller: TextEditingController(
                              text: _userRole.toUpperCase(),
                            ),
                            label: 'Account Classification Role',
                            prefixIcon: Icons.gavel_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // --- CONDITIONAL FIELDS BASED ON ROLE SEGMENTATION ---
                      if (_userRole == 'individual') ...[
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
                          text: _newDocFileName != null
                              ? 'New Verification ID Staged'
                              : 'Replace National ID Document',
                          onPressed: _pickNewDocument,
                        ),
                        if (_newDocFileName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pending document update: $_newDocFileName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else if (_existingDocUrl != null) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '🔒 Identification document saved securely',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
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
                          text: _newDocFileName != null
                              ? 'New Permit Document Staged'
                              : 'Update Business Permit Documentation',
                          onPressed: _pickNewDocument,
                        ),
                        if (_newDocFileName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pending document update: $_newDocFileName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else if (_existingDocUrl != null) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '🔒 Organization validation records saved on server',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
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
                            return 'Enter complete 11-digit mobile number';
                          if (!val.startsWith('09'))
                            return 'Must be a valid PH mobile number starting with 09';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // --- ADDRESS SPECIFICATIONS ---
                      const Text(
                        'Address Specifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
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

                      // --- DROPDOWN LOCATION SELECTORS ---
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
                                    (p) => DropdownMenuItem(
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
                                    (c) => DropdownMenuItem(
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
                                if (val != null && _selectedProvince != null) {
                                  _updateBarangaysList(_selectedProvince!, val);
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
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedBarangay = val),
                      ),
                      const SizedBox(height: 36),

                      CustomButton(
                        text: 'Save Details',
                        onPressed: _handleSaveChanges,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
