import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../widgets/section_widgets.dart';
import '../../tree_cutting/tree_cutting_justification_guidelines_screen.dart';

/// Self-check list shown before applying for a tree-cutting permit.
/// Progress is a local reminder only and is not persisted.
class ApplicationReadinessCard extends StatefulWidget {
  const ApplicationReadinessCard({super.key});

  @override
  State<ApplicationReadinessCard> createState() =>
      _ApplicationReadinessCardState();
}

class _ApplicationReadinessCardState extends State<ApplicationReadinessCard> {
  static const _steps = [
    'Choose recipient authority: LGU or DENR-CENRO',
    'Upload Section B documents: Request Letter and LGU/Barangay No Objection',
    'Attach tree target photos (field photographs)',
  ];

  final List<bool> _done = List.filled(_steps.length, false);

  @override
  Widget build(BuildContext context) {
    final completed = _done.where((d) => d).length;
    final progress = completed / _steps.length;
    final color = progress == 1 ? AppColors.statusApproved : AppColors.primary;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Permit Application Checklist',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$completed of ${_steps.length}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < _steps.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _done[i],
              onChanged: (v) => setState(() => _done[i] = v ?? false),
              title: Text(
                'Step ${i + 1}: ${_steps[i]}',
                style: TextStyle(
                  fontSize: 13,
                  color: _done[i] ? AppColors.textGrey : AppColors.textDark,
                  decoration: _done[i] ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const TreeCuttingJustificationGuidelinesScreen(),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Read the guidelines'),
            ),
          ),
        ],
      ),
    );
  }
}
