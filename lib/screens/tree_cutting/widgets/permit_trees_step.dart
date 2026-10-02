import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../widgets/section_widgets.dart';
import '../tree_cutting_form_model.dart';
import '../tree_cutting_justification_guidelines_screen.dart';
import 'permit_dropdown.dart';

class PermitTreesStep extends StatelessWidget {
  const PermitTreesStep({
    super.key,
    required this.model,
    required this.formKey,
    required this.onIdentifySpecies,
    required this.onPickLocation,
  });

  final TreeCuttingFormModel model;
  final GlobalKey<FormState> formKey;
  final VoidCallback onIdentifySpecies;
  final VoidCallback onPickLocation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final enabled = !model.submitting;
        return Form(
          key: formKey,
          child: Column(
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      icon: Icons.park_outlined,
                      label: 'The Trees',
                      subtitle: 'Tell us which trees and why',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: enabled ? onIdentifySpecies : null,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Identify species with camera'),
                    ),
                    if (model.speciesIdentification?.bestMatch
                        case final match?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.fade(0.08),
                          borderRadius: AppRadius.smAll,
                          border: Border.all(
                            color: AppColors.primary.fade(0.2),
                          ),
                        ),
                        child: Text(
                          'Suggested: ${match.displayName} '
                          '(${match.confidencePercent}% confidence). '
                          'You can change it below.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PermitDropdown(
                      label: 'Tree species',
                      value: model.selectedSpecies,
                      options: TreeCuttingFormModel.treeVariants,
                      enabled: enabled,
                      onChanged: model.setSpecies,
                      validator: (v) => v == null ? 'Choose a species' : null,
                    ),
                    if (model.showCustomSpecies) ...[
                      const SizedBox(height: AppSpacing.md),
                      CustomTextField(
                        controller: model.kindOfTree,
                        label: 'Species name',
                        prefixIcon: Icons.edit_outlined,
                        enabled: enabled,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter the species name'
                            : null,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PermitDropdown(
                      label: 'Number of trees',
                      value: model.selectedCount,
                      options: TreeCuttingFormModel.countOptions,
                      enabled: enabled,
                      onChanged: model.setCount,
                      validator: (v) => v == null ? 'Choose a number' : null,
                    ),
                    if (model.showCustomCount) ...[
                      const SizedBox(height: AppSpacing.md),
                      CustomTextField(
                        controller: model.numberOfTrees,
                        label: 'Exact number of trees',
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        enabled: enabled,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null || n < 1
                              ? 'Enter a whole number'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PermitDropdown(
                      label: 'Reason for request',
                      value: model.selectedReason,
                      options: TreeCuttingFormModel.reasons,
                      enabled: enabled,
                      onChanged: model.setReason,
                      validator: (v) => v == null ? 'Choose a reason' : null,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const TreeCuttingJustificationGuidelinesScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('What makes a valid reason?'),
                      ),
                    ),
                    if (model.showCustomReason) ...[
                      CustomTextField(
                        controller: model.reasonForRequest,
                        label: 'Explain your reason',
                        prefixIcon: Icons.notes_outlined,
                        maxLines: 3,
                        enabled: enabled,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Describe your reason'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    CustomTextField(
                      controller: model.remarks,
                      label: 'Additional remarks (optional)',
                      prefixIcon: Icons.sticky_note_2_outlined,
                      maxLines: 2,
                      enabled: enabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      icon: Icons.location_on_outlined,
                      label: 'Location of the Trees',
                      subtitle: 'Pin the exact spot on the map',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormField<bool>(
                      key: ValueKey(model.hasCoordinates),
                      validator: (_) => model.hasCoordinates
                          ? null
                          : 'Pin the trees on the map to continue',
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LocationSummary(model: model),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: enabled ? onPickLocation : null,
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: Text(
                              model.hasCoordinates
                                  ? 'Change location on map'
                                  : 'Pick location on map',
                            ),
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                left: AppSpacing.xs,
                              ),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PermitDropdown(
                      label: 'Type of site',
                      value: model.siteType,
                      options: const [
                        TreeCuttingFormModel.siteSchool,
                        TreeCuttingFormModel.sitePrivate,
                      ],
                      labels: const {
                        TreeCuttingFormModel.siteSchool: 'School grounds',
                        TreeCuttingFormModel.sitePrivate:
                            'Private or other property',
                      },
                      helperText:
                          'School grounds need a PTA President certification',
                      enabled: enabled,
                      onChanged: model.setSiteType,
                      validator: (v) => v == null ? 'Choose the site type' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({required this.model});

  final TreeCuttingFormModel model;

  @override
  Widget build(BuildContext context) {
    if (!model.hasCoordinates) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.orange.fade(0.1),
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Location not set yet',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.fade(0.06),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.primary.fade(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Location set',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DetailRow(label: 'Barangay', value: model.barangay.text, labelWidth: 90),
          DetailRow(label: 'Street', value: model.street.text, labelWidth: 90),
          DetailRow(
            label: 'Landmark',
            value: model.landmark.text,
            labelWidth: 90,
          ),
          DetailRow(
            label: 'Address',
            value: model.fullAddress.text,
            labelWidth: 90,
          ),
        ],
      ),
    );
  }
}
