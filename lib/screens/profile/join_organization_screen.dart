import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/static_location_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/organization_registration_service.dart';
import '../../widgets/custom_button.dart';

class JoinOrganizationScreen extends StatefulWidget {
  const JoinOrganizationScreen({super.key});

  @override
  State<JoinOrganizationScreen> createState() => _JoinOrganizationScreenState();
}

class _JoinOrganizationScreenState extends State<JoinOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _permitIssuerController = TextEditingController();
  final _permitNumberController = TextEditingController();
  final _representativeController = TextEditingController();
  String? _selectedProvince;
  String? _selectedCity;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _legalNameController.dispose();
    _permitIssuerController.dispose();
    _permitNumberController.dispose();
    _representativeController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    setState(() => _isSubmitting = true);
    try {
      await const OrganizationRegistrationService().requestRepresentative({
        'legalName': _legalNameController.text.trim(),
        'permitIssuer': _permitIssuerController.text.trim(),
        'permitNumber': _permitNumberController.text.trim(),
        'contactPerson': _representativeController.text.trim(),
        'addressDetails': {
          'city': _selectedCity ?? '',
          'province': _selectedProvince ?? '',
        },
      });
      if (!mounted) return;
      await authProvider.reloadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request received. MENRO will review the organization and representative details.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on OrganizationFunctionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to submit the request. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required field' : null;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final contactPerson = user?.contactPerson?.trim() ?? '';
    if (_representativeController.text.isEmpty && contactPerson.isNotEmpty) {
      _representativeController.text = contactPerson;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Request Organization Access')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Organization details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _formField(
                controller: _legalNameController,
                label: 'Legal organization name',
                validator: _required,
              ),
              _formField(
                controller: _permitIssuerController,
                label: 'Permit issuing authority',
                validator: _required,
              ),
              _formField(
                controller: _permitNumberController,
                label: 'Business permit number',
                validator: _required,
              ),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Province on permit',
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
                        child: Text(province, overflow: TextOverflow.ellipsis),
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
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'City / municipality on permit',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Select a city' : null,
                items: citiesForProvince(_selectedProvince)
                    .map(
                      (city) => DropdownMenuItem(
                        value: city,
                        child: Text(city, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _selectedProvince == null
                    ? null
                    : (city) => setState(() => _selectedCity = city),
              ),
              const SizedBox(height: 12),
              const Text(
                'Representative',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _formField(
                controller: _representativeController,
                label: 'Authorized contact person full name',
                validator: _required,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 0, bottom: 12),
                child: Text(
                  'Enter the representative’s personal name, not the organization name.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Requests are reviewed before organization access is granted.',
                style: TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _isSubmitting ? 'Submitting...' : 'Submit Request',
                onPressed: _isSubmitting ? null : _submitRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
