import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class TreeCuttingJustificationGuidelinesScreen extends StatelessWidget {
  const TreeCuttingJustificationGuidelinesScreen({super.key});

  static const List<_ReasonGuideline> reasons = [
    _ReasonGuideline(
      title: 'Poses structural hazard to house / property',
      whatItMeans:
          'The tree displays physical traits or proximity that threaten the integrity of a building, foundation, or permanent structure.',
      imageAsset: 'assets/images/trees/structural_hazard.jpg',
      evidence: [
        'Photos showing proximity (distance in meters)',

        'Visible cracks in foundations caused by roots',
        'Branches hanging directly over roof lines',
      ],
      typicalNotes: [
        'Mention the age of the tree',
        'Clarify whether the structure is residential or commercial',
      ],
      mistakesToAvoid: [
        'Do not claim a hazard if the tree is simply “too close” without visible evidence of damage or structural stress.',
      ],
      citation: 'LGU Building Code & Safety Regulations',
    ),
    _ReasonGuideline(
      title: 'Interference with electric powerlines / utilities',
      whatItMeans:
          'The tree branches are in contact with or dangerously close to active electric wires, water pipes, or telecommunication lines.',
      imageAsset: 'assets/images/trees/interference_powerlines.jpg',
      evidence: [
        'Clear photos of branches touching lines',
        'Charred bark from previous sparks',
        'Wires visible through the foliage',
      ],
      typicalNotes: [
        'Include the name of the utility provider if already assessed',
      ],
      mistakesToAvoid: [
        'Do not attempt to prune or cut these trees yourself; this is a safety violation. Always seek utility provider coordination first.',
      ],
      citation: 'National Electrical Code / Utility Provider Safety Protocols',
    ),
    _ReasonGuideline(
      title: 'Tree is diseased, dead, or decaying',
      whatItMeans:
          'The tree is structurally compromised due to biological failure, rot, pest infestation, or natural senescence.',
      imageAsset: 'assets/images/trees/dead_tree.jpg',
      evidence: [
        'Photos of fungal growth (mushrooms)',
        'Significant hollows in the trunk',
        'Withered/bare branches or leaning at an unstable angle',
      ],
      typicalNotes: [
        'Include the specific disease type if known (e.g., trunk rot, termite infestation)',
      ],
      mistakesToAvoid: [
        'Do not confuse seasonal leaf shedding or minor thinning with actual disease.',
      ],
      citation: 'DENR Forestry Bureau Guidelines',
    ),
    _ReasonGuideline(
      title: 'Obstructing authorized road/infrastructure construction',
      whatItMeans:
          'The tree sits within the planned footprint of an approved, documented construction project (e.g., road widening, driveway, or building).',
      imageAsset: 'assets/images/trees/obstructing_construction.jpg',
      evidence: [
        'Approved construction permit copy',
        'Site map or blueprints showing tree location relative to the project',
      ],
      typicalNotes: [
        'Cite the specific project permit number and approval date',
      ],
      mistakesToAvoid: [
        'Failing to provide the approved construction site plan.',
      ],
      citation: 'DPWH/City Engineering Office Approved Plans',
    ),
    _ReasonGuideline(
      title: 'Agricultural clearing / personal land re-development',
      whatItMeans:
          'The tree removal is required to prepare the land for legitimate agricultural use (farming) or authorized residential/commercial site development.',
      imageAsset: 'assets/images/trees/agri_clearing.jpg',
      evidence: [
        'Land title / proof of ownership',
        'Tax Declaration',
        'Brief description of the intended land use',
      ],
      typicalNotes: [
        'Clarify if this is for subsistence farming or commercial development',
      ],
      mistakesToAvoid: [
        'Attempting to clear land for “vacant lot” purposes without a clear plan for use.',
      ],
      citation: 'DENR Land Conversion Guidelines',
    ),
    _ReasonGuideline(
      title: 'Others (Provide manual reason)',
      whatItMeans:
          'A situation that does not fit into standard categories but requires tree removal for an urgent or justified reason.',
      evidence: [
        'A detailed narrative statement',
        'High-quality photos from multiple angles',
      ],
      typicalNotes: [
        'Provide as much context as possible (why pruning/relocation is not viable)',
      ],
      mistakesToAvoid: [
        'Being vague (e.g., “I don’t like it”). Clearly explain the necessity of removal.',
      ],
      citation: 'MENRO Evaluation Policy',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tree Cutting Justification Guidelines'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reasons.length,
        itemBuilder: (context, i) {
          final r = reasons[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ReasonCard(guideline: r),
          );
        },
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final _ReasonGuideline guideline;

  const _ReasonCard({required this.guideline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (guideline.imageAsset != null &&
              guideline.imageAsset!.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                guideline.imageAsset!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (guideline.imageAsset != null &&
              guideline.imageAsset!.trim().isNotEmpty)
            const SizedBox(height: 12),
          Text(
            guideline.title,

            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            guideline.whatItMeans,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _Section(title: 'Evidence / Examples', items: guideline.evidence),
          if (guideline.typicalNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(title: 'Typical notes', items: guideline.typicalNotes),
          ],
          if (guideline.mistakesToAvoid.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Common mistakes to avoid',
              items: guideline.mistakesToAvoid,
            ),
          ],
          if (guideline.citation != null &&
              guideline.citation!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.18)),
              ),
              child: Text(
                guideline.citation!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> items;

  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonGuideline {
  final String title;
  final String whatItMeans;
  final List<String> evidence;
  final List<String> typicalNotes;
  final List<String> mistakesToAvoid;
  final String? citation;
  final String? imageAsset;

  const _ReasonGuideline({
    required this.title,
    required this.whatItMeans,
    required this.evidence,
    this.typicalNotes = const [],
    this.mistakesToAvoid = const [],
    this.citation,
    this.imageAsset,
  });
}
