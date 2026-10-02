import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../widgets/section_widgets.dart';

class ReportLocationCard extends StatelessWidget {
  const ReportLocationCard({
    super.key,
    required this.barangayController,
    required this.streetController,
    required this.landmarkController,
    required this.addressController,
    required this.isFetching,
    required this.hasCoordinates,
    required this.onRefreshGps,
    required this.onPickOnMap,
  });

  final TextEditingController barangayController;
  final TextEditingController streetController;
  final TextEditingController landmarkController;
  final TextEditingController addressController;
  final bool isFetching;
  final bool hasCoordinates;
  final VoidCallback onRefreshGps;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.location_on_outlined,
            label: 'Incident Location',
            subtitle: 'Use GPS or pin the exact spot on the map',
          ),
          const SizedBox(height: AppSpacing.md),
          _LocationStatus(isFetching: isFetching, hasCoordinates: hasCoordinates),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Use GPS to get current location',
                  button: true,
                  enabled: !isFetching,
                  onTap: isFetching ? null : onRefreshGps,
                  child: OutlinedButton.icon(
                    onPressed: isFetching ? null : onRefreshGps,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Use GPS'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  label: 'Pick location on the map',
                  button: true,
                  enabled: !isFetching,
                  onTap: isFetching ? null : onPickOnMap,
                  child: OutlinedButton.icon(
                    onPressed: isFetching ? null : onPickOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Pick on map'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _ReadOnlyField(
            controller: barangayController,
            label: 'Barangay',
            icon: Icons.home_work_outlined,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Set the location with GPS or the map to fill in the barangay'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _ReadOnlyField(
            controller: streetController,
            label: 'Street / Sitio',
            icon: Icons.add_road,
          ),
          const SizedBox(height: AppSpacing.md),
          _ReadOnlyField(
            controller: landmarkController,
            label: 'Nearest Landmark',
            icon: Icons.pin_drop_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          _ReadOnlyField(
            controller: addressController,
            label: 'Complete Address',
            icon: Icons.explore_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.isFetching, required this.hasCoordinates});

  final bool isFetching;
  final bool hasCoordinates;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String text;
    if (isFetching) {
      color = AppColors.textGrey;
      icon = Icons.gps_not_fixed;
      text = 'Finding your location...';
    } else if (hasCoordinates) {
      color = AppColors.statusApproved;
      icon = Icons.check_circle_outline;
      text = 'Location set';
    } else {
      color = Colors.orange.shade800;
      icon = Icons.info_outline;
      text = 'Location not set yet';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.fade(0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: [
          if (isFetching)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
    );
  }
}
