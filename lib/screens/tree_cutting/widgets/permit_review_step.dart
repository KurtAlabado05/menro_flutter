import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../widgets/section_widgets.dart';
import '../tree_cutting_form_model.dart';

class PermitReviewStep extends StatelessWidget {
  const PermitReviewStep({
    super.key,
    required this.model,
    required this.formKey,
    required this.onEditStep,
  });

  final TreeCuttingFormModel model;
  final GlobalKey<FormState> formKey;
  final ValueChanged<int> onEditStep;

  String get _actionText => switch (model.action) {
    PermitAction.cutting => 'Tree cutting',
    PermitAction.trimming => 'Trimming / pruning',
    PermitAction.others => 'Other: ${model.othersAction.text.trim()}',
  };

  String get _authorityText =>
      model.targetAuthority == TreeCuttingFormModel.authorityDenr
      ? 'DENR-CENRO'
      : 'Local Government Unit';

  String get _countText => model.showCustomCount
      ? model.numberOfTrees.text.trim()
      : (model.selectedCount ?? '');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final docCount =
            [
              model.requestLetterUrl,
              model.lguCertificationUrl,
              model.landTitleUrl,
              model.ptaCertificationUrl,
            ].where((u) => u != null && u.isNotEmpty).length +
            model.treePhotoUrls.length +
            model.contextPhotoUrls.length;

        return Form(
          key: formKey,
          child: Column(
            children: [
              if (model.submitting) ...[
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Checking all tree photos and submitting your application...',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (model.photoError != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    model.photoError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _ReviewCard(
                title: 'Applicant',
                onEdit: () => onEditStep(0),
                children: [
                  DetailRow(label: 'Name', value: model.applicantName.text),
                  DetailRow(label: 'Address', value: model.address.text),
                  DetailRow(label: 'Contact', value: model.contactNumber.text),
                  DetailRow(label: 'Email', value: model.email.text),
                  DetailRow(label: 'Request', value: _actionText),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ReviewCard(
                title: 'Trees and location',
                onEdit: () => onEditStep(1),
                children: [
                  DetailRow(label: 'Species', value: model.kindOfTree.text),
                  DetailRow(label: 'Number', value: _countText),
                  DetailRow(
                    label: 'Reason',
                    value: model.reasonForRequest.text,
                  ),
                  DetailRow(label: 'Barangay', value: model.barangay.text),
                  DetailRow(label: 'Address', value: model.fullAddress.text),
                  DetailRow(
                    label: 'Site',
                    value: model.isSchoolGrounds
                        ? 'School grounds'
                        : 'Private or other property',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ReviewCard(
                title: 'Documents',
                onEdit: () => onEditStep(2),
                children: [
                  DetailRow(label: 'Send to', value: _authorityText),
                  DetailRow(
                    label: 'Files',
                    value:
                        '$docCount uploaded '
                        '(${model.treePhotoUrls.length} tree photos)',
                  ),
                  if (model.requiresSpeciesInspection)
                    DetailRow(
                      label: 'Species check',
                      value:
                          '${model.unverifiedTreePhotoUrls.length} on-site photo(s); '
                          'species will be verified at the site inspection',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      icon: Icons.verified_user_outlined,
                      label: 'Declaration',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Text(
                        'I certify that all information and uploaded files '
                        'in this application are complete and true.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    FormField<bool>(
                      initialValue: model.declarationChecked,
                      validator: (_) => model.declarationChecked
                          ? null
                          : 'Please confirm the declaration to submit',
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            type: MaterialType.transparency,
                            child: CheckboxListTile(
                              value: model.declarationChecked,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              enabled: !model.submitting,
                              title: const Text(
                                'I agree with the declaration above',
                                style: TextStyle(fontSize: 13),
                              ),
                              onChanged: (v) {
                                model.setDeclaration(v ?? false);
                                state.didChange(v);
                              },
                            ),
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.onEdit,
    required this.children,
  });

  final String title;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text('Edit', semanticsLabel: 'Edit $title'),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
