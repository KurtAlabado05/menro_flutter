import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/static_location_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloudinary_image_service.dart';
import '../../services/organization_registration_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class OrganizationApplicationScreen extends StatefulWidget {
  const OrganizationApplicationScreen({super.key});

  @override
  State<OrganizationApplicationScreen> createState() =>
      _OrganizationApplicationScreenState();
}

class _OrganizationApplicationScreenState
    extends State<OrganizationApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _permitNumberController = TextEditingController();
  final _permitIssuerController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedCity;
  String? _selectedProvince;

  Uint8List? _permitBytes;
  String? _permitFileName;
  bool _isSubmitting = false;

  final _cloudinary = const CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  @override
  void dispose() {
    _legalNameController.dispose();
    _contactPersonController.dispose();
    _permitNumberController.dispose();
    _permitIssuerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required field' : null;

  Future<void> _pickPermit() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null || !mounted) return;
    setState(() {
      _permitBytes = result.files.single.bytes;
      _permitFileName = result.files.single.name;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_permitBytes == null || _permitFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload the organization business permit to continue.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) {
        throw const OrganizationFunctionException(
          'unauthenticated',
          'Sign in before submitting an organization application.',
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadName =
          'organization_permits/${user.id}/permit_${timestamp}_${_permitFileName!}';
      final permitUrl = _permitFileName!.toLowerCase().endsWith('.pdf')
          ? await _cloudinary.uploadRawFile(
              bytes: _permitBytes!,
              fileName: uploadName,
            )
          : await _cloudinary.uploadImage(
              bytes: _permitBytes!,
              fileName: uploadName,
            );

      await const OrganizationRegistrationService().submitApplication({
        'legalName': _legalNameController.text.trim(),
        'permitIssuer': _permitIssuerController.text.trim(),
        'permitNumber': _permitNumberController.text.trim(),
        'permitDocumentUrl': permitUrl,
        'contactPerson': _contactPersonController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'addressDetails': {
          'city': _selectedCity ?? '',
          'province': _selectedProvince ?? '',
        },
      });

      if (!mounted) return;
      await context.read<AuthProvider>().reloadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization application submitted for MENRO review.'),
        ),
      );
      Navigator.pop(context, true);
    } on OrganizationFunctionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to submit application: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final email = user?.email ?? '';
    final legalName = user?.name.trim() ?? '';
    final contactPerson = user?.contactPerson?.trim() ?? '';
    final permitNumber = user?.businessPermitNumber?.trim() ?? '';
    final phoneNumber = user?.phoneNumber?.trim() ?? '';
    final addressParts = (user?.completeAddress ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final savedCity = addressParts.length >= 2
        ? addressParts[addressParts.length - 2]
        : '';
    final savedProvince = addressParts.length >= 2 ? addressParts.last : '';
    if (_selectedProvince == null &&
        staticLocationData[savedProvince]?.containsKey(savedCity) == true) {
      _selectedProvince = savedProvince;
      _selectedCity = savedCity;
    }
    if (_legalNameController.text.isEmpty &&
        legalName.isNotEmpty &&
        legalName != 'User') {
      _legalNameController.text = legalName;
    }
    if (_contactPersonController.text.isEmpty && contactPerson.isNotEmpty) {
      _contactPersonController.text = contactPerson;
    }
    if (_permitNumberController.text.isEmpty && permitNumber.isNotEmpty) {
      _permitNumberController.text = permitNumber;
    }
    if (_phoneController.text.isEmpty && phoneNumber.isNotEmpty) {
      _phoneController.text = phoneNumber;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Organization application')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Complete your organization application',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Submit the legal organization details and permit for MENRO review. Organization access is granted after approval.',
                style: TextStyle(color: AppColors.textGrey, height: 1.4),
              ),
              const SizedBox(height: 20),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Signed-in email',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                child: Text(email),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _legalNameController,
                label: 'Legal organization name',
                prefixIcon: Icons.business_outlined,
                validator: _required,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _contactPersonController,
                label: 'Authorized contact person',
                prefixIcon: Icons.person_outline,
                validator: _required,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _permitNumberController,
                label: 'Business / Mayor\'s permit number',
                prefixIcon: Icons.badge_outlined,
                validator: _required,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _permitIssuerController,
                label: 'Permit issuing authority',
                prefixIcon: Icons.account_balance_outlined,
                validator: _required,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedProvince,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Province',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null ? 'Select a province' : null,
                      items: staticProvinces
                          .map(
                            (province) => DropdownMenuItem(
                              value: province,
                              child: Text(
                                province,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (province) {
                        setState(() {
                          _selectedProvince = province;
                          _selectedCity = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'City / municipality',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null ? 'Select a city' : null,
                      items: citiesForProvince(_selectedProvince)
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(
                                city,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _selectedProvince == null
                          ? null
                          : (city) => setState(() => _selectedCity = city),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'Phone number (optional)',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: _permitFileName == null
                    ? 'Upload business permit'
                    : 'Replace business permit',
                icon: Icons.upload_file_outlined,
                onPressed: _isSubmitting ? null : _pickPermit,
              ),
              const SizedBox(height: 8),
              Text(
                _permitFileName ?? 'Accepted formats: JPG, PNG, or PDF.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _isSubmitting ? 'Submitting…' : 'Submit application',
                icon: Icons.send_outlined,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
