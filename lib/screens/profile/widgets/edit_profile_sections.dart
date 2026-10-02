import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/section_widgets.dart';

export '../../../widgets/address_fields.dart';
export '../../../widgets/form_validators.dart';

class LockedInfoCard extends StatelessWidget {
  const LockedInfoCard({
    super.key,
    required this.title,
    required this.rows,
    this.footnote,
  });

  final String title;
  final List<({String label, String value})> rows;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.lock_outline_rounded,
            label: title,
            subtitle: 'These details cannot be edited here.',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            DetailRow(
              label: row.label,
              value: row.value.trim().isEmpty ? 'Not provided' : row.value,
            ),
          if (footnote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: AppColors.statusPending,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    footnote!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusPending,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class DocumentReplaceTile extends StatelessWidget {
  const DocumentReplaceTile({
    super.key,
    required this.buttonLabel,
    required this.savedMessage,
    required this.hasExisting,
    required this.stagedFileName,
    required this.onPick,
  });

  final String buttonLabel;
  final String savedMessage;
  final bool hasExisting;
  final String? stagedFileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomButton(
          text: buttonLabel,
          icon: Icons.upload_file_outlined,
          isOutlined: true,
          onPressed: onPick,
        ),
        if (stagedFileName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Will upload on save: $stagedFileName',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.statusApproved,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else if (hasExisting) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            savedMessage,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        ],
      ],
    );
  }
}
