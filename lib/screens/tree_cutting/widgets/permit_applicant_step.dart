import 'package:flutter/material.dart';

import '../../../core/constants/app_tokens.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../widgets/section_widgets.dart';
import '../tree_cutting_form_model.dart';

class PermitApplicantStep extends StatelessWidget {
  const PermitApplicantStep({
    super.key,
    required this.model,
    required this.formKey,
  });

  final TreeCuttingFormModel model;
  final GlobalKey<FormState> formKey;

  static final RegExp _emailPattern = RegExp(
    r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$',
  );

  static const Map<PermitAction, String> _actionLabels = {
    PermitAction.cutting: 'Tree cutting',
    PermitAction.trimming: 'Trimming / pruning',
    PermitAction.others: 'Other',
  };

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
                      icon: Icons.person_outline,
                      label: 'Applicant',
                      subtitle: 'Filled in from your account. Edit if needed.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CustomTextField(
                      controller: model.applicantName,
                      label: 'Full name',
                      prefixIcon: Icons.badge_outlined,
                      enabled: enabled,
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter the applicant name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: model.address,
                      label: 'Home address',
                      prefixIcon: Icons.home_outlined,
                      maxLines: 2,
                      enabled: enabled,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter your address'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: model.contactNumber,
                      label: 'Contact number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      enabled: enabled,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter a contact number';
                        }
                        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                        return digits.length < 10
                            ? 'Enter a valid contact number'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: model.email,
                      label: 'Email address',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      enabled: enabled,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email address';
                        }
                        return _emailPattern.hasMatch(v.trim())
                            ? null
                            : 'Enter a valid email address';
                      },
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
                      icon: Icons.assignment_outlined,
                      label: 'What do you need?',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final entry in _actionLabels.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: model.action == entry.key,
                            onSelected: enabled
                                ? (_) => model.setAction(entry.key)
                                : null,
                          ),
                      ],
                    ),
                    if (model.action == PermitAction.others) ...[
                      const SizedBox(height: AppSpacing.md),
                      CustomTextField(
                        controller: model.othersAction,
                        label: 'Describe the action',
                        prefixIcon: Icons.edit_outlined,
                        enabled: enabled,
                        validator: (_) => model.validateActionType(),
                      ),
                    ],
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
