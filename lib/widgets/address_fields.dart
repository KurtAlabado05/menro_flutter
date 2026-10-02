import 'package:flutter/material.dart';

import '../core/constants/app_tokens.dart';
import '../core/constants/static_location_data.dart';
import 'custom_textfield.dart';
import 'form_validators.dart';

/// Shared house/sitio + cascading province/city/barangay fields, used by
/// registration and profile editing so both stay in sync with
/// [staticLocationData].
class AddressFields extends StatelessWidget {
  const AddressFields({
    super.key,
    required this.houseController,
    required this.sitioController,
    required this.province,
    required this.city,
    required this.barangay,
    required this.onProvinceChanged,
    required this.onCityChanged,
    required this.onBarangayChanged,
  });

  final TextEditingController houseController;
  final TextEditingController sitioController;
  final String? province;
  final String? city;
  final String? barangay;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onBarangayChanged;

  @override
  Widget build(BuildContext context) {
    final cities = citiesForProvince(province);
    final barangays = barangaysForCity(province, city);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: houseController,
          label: 'Bldg / House No.',
          prefixIcon: Icons.tag,
          textInputAction: TextInputAction.next,
          validator: (v) => requiredField(v, 'Required'),
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomTextField(
          controller: sitioController,
          label: 'Sitio / Street',
          prefixIcon: Icons.add_road,
          textInputAction: TextInputAction.next,
          validator: (v) => requiredField(v, 'Required'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _LocationDropdown(
          key: const ValueKey('province'),
          label: 'Province',
          value: province,
          options: staticProvinces,
          onChanged: onProvinceChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _LocationDropdown(
          key: ValueKey('city-$province'),
          label: 'City / Municipality',
          value: city,
          options: cities,
          onChanged: province == null ? null : onCityChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _LocationDropdown(
          key: ValueKey('barangay-$province-$city'),
          label: 'Barangay',
          value: barangay,
          options: barangays,
          onChanged: city == null ? null : onBarangayChanged,
        ),
      ],
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Select a ${label.toLowerCase()}' : null,
    );
  }
}
