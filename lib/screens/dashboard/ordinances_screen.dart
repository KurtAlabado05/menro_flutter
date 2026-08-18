import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class OrdinancesScreen extends StatelessWidget {
  String _categoryLabelFromTitle(String title) {
    final t = title.toLowerCase();

    // Mirror ReportScreen category dropdown values
    if (t.contains('smoking')) {
      return 'Public smoking violation';
    }
    if (t.contains('illegal dumping') ||
        t.contains('dumping') ||
        t.contains('basura') ||
        t.contains('tapon')) {
      return 'Illegal Dumping of Solid Waste';
    }
    if (t.contains('burning') ||
        t.contains('anti-burning') ||
        t.contains('open burning')) {
      return 'Open Burning of Waste';
    }
    if (t.contains('liquid') ||
        t.contains('likido') ||
        t.contains('wastewater') ||
        t.contains('grease')) {
      return 'Improper Liquid/Wastewater Disposal';
    }
    if (t.contains('waterway') ||
        t.contains('rivers') ||
        t.contains('ilog') ||
        t.contains('waterway pollution')) {
      return 'Waterway Pollution';
    }

    // Fallback: treat generic cleanliness/sanitation ordinances as littering/vandalism category
    return 'Littering / Public vandalism';
  }

  const OrdinancesScreen({super.key});

  static const String _legalDisclaimer =
      'Penalties are based on prevailing local government standards and may be subject to city-wide updates. Please contact the City Environment and Natural Resources Office (MENRO) for official legal citations.';

  // Category options mirror ReportScreen dropdown values.
  // Each ordinance is mapped to one of these categories so the dialog can display it consistently.
  final List<_OrdinanceCardModel> _ordinances = const [
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/no_smoking.png',
      title: 'No Smoking (Smoke-Free Ordinance)',
      description:
          'Regulates the use, sale, and distribution of tobacco products to protect public health from secondhand smoke.',
      prohibited: [
        'Smoking in public places and workplaces',
        'Smoking in enclosed areas',
        'Smoking within 100 meters of schools, playgrounds, or facilities frequented by minors',
      ],
      penalties:
          'Fines (typically ₱500–₱2,000 for first offense) and/or mandatory community service.',
      whereApplies:
          'Citywide; all public buildings, public transport, and designated smoke-free zones.',
      source: 'RA 9211 (Tobacco Regulation Act) & Local Smoke-Free Ordinances.',
    ),
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/no_illegal_dumping.png',
      title: 'No Illegal Dumping',
      description:
          'Mandates proper disposal of trash to prevent clogging of drainage and environmental degradation.',
      prohibited: [
        'Dumping trash in canals, streets, sidewalks, vacant lots, or rivers',
        'Disposing refuse in non-designated disposal sites',
      ],
      penalties:
          'Fines starting at ₱1,000; repeat offenders may face closure of establishment (if business) or community service.',
      whereApplies:
          'All public streets, drainage systems, and non-designated disposal sites.',
      source: 'RA 9003 & Local Solid Waste Management Ordinance.',
    ),
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/no_burning_of_waste.png',
      title: 'No Burning of Waste (Anti-Burning)',
      description:
          'Prohibits open burning of solid waste to prevent air pollution and fire hazards.',
      prohibited: [
        'Burning plastic, rubber, household trash, or garden waste in open areas',
      ],
      penalties:
          'Administrative fines ranging from ₱500 to ₱5,000, or criminal charges under the Clean Air Act.',
      whereApplies:
          'Residential areas, private lots, and public spaces citywide.',
      source: 'RA 8749 (Philippine Clean Air Act).',
    ),
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/kung_hindi_mo_kayang_linisin.png',
      title: 'Responsibility for Waste/Cleanliness',
      description:
          '“My Vicinity, My Responsibility” — keeping cleanliness in your immediate environment.',
      prohibited: [
        'Leaving trash outside one’s property outside of official collection hours',
        'Allowing waste to accumulate on sidewalks fronting one’s property',
      ],
      penalties: 'Fines for sanitary violations; “clean-up” orders.',
      whereApplies: 'Frontage of all residential and commercial properties.',
      source: 'Local Solid Waste Management Ordinance.',
    ),
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/bawal_magtapon_ng_likido.png',
      title: 'Proper Disposal of Liquids',
      description:
          'Prevents contamination of waterways through the discharge of untreated liquid waste.',
      prohibited: [
        'Direct discharge of wastewater, oil, or kitchen grease into public drainage',
        'Disposing untreated oily/liquid waste into bodies of water',
      ],
      penalties:
          'Significant fines; mandatory installation of grease traps/septic treatment; possible business permit revocation.',
      whereApplies:
          'Commercial establishments (restaurants, car washes) and households.',
      source: 'Philippine Clean Water Act / Sanitation Code.',
    ),
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/bawal_magtapon_ng_basura.jpg',
      title: 'Mandatory Waste Segregation',
      description:
          'Requires households and establishments to segregate waste at the source (biodegradable, recyclable, residual).',
      prohibited: [
        'Mixing different types of waste in one container',
        'Non-compliance with “No Segregation, No Collection” policy',
      ],
      penalties:
          'Refusal of garbage collection; fines for repeated non-compliance.',
      whereApplies:
          'All households, business establishments, and institutions.',
      source: 'RA 9003.',
    ),
    _OrdinanceCardModel(
      imagePath: 'assets/images/ordinances/bawal_magtapon_sa_mga_ilog.png',
      title: 'Protection of Waterways (No Dumping in Rivers)',
      description:
          'Specifically targets the preservation of Baliuag’s river systems and aquatic ecosystems.',
      prohibited: [
        'Throwing any trash, debris, or hazardous substances into rivers, streams, or creeks',
      ],
      penalties:
          'Heavy fines; potential criminal prosecution under the Clean Water Act.',
      whereApplies: 'Areas within 100 meters of rivers and natural waterways.',
      source: 'Local Environmental Code / Clean Water Act.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baliwag Environmental Codes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _ordinances.length,
        itemBuilder: (context, index) {
          final ordinance = _ordinances[index];
          return InkWell(
            onTap: () => _showOrdinanceDetails(context, ordinance),
            child: Image.asset(ordinance.imagePath, fit: BoxFit.cover),
          );
        },
      ),
    );
  }

  void _showOrdinanceDetails(
    BuildContext context,
    _OrdinanceCardModel ordinance,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ordinance.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.asset(
                          ordinance.imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ordinance.description,
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    _InfoSection(
                      title: 'Category',
                      value: _categoryLabelFromTitle(ordinance.title),
                    ),

                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'What’s Prohibited',
                      items: ordinance.prohibited,
                    ),
                    const SizedBox(height: 12),
                    _InfoSection(
                      title: 'Penalties',
                      value: ordinance.penalties,
                    ),
                    const SizedBox(height: 12),
                    _InfoSection(
                      title: 'Where it applies',
                      value: ordinance.whereApplies,
                    ),
                    const SizedBox(height: 12),
                    _InfoSection(
                      title: 'Source/Citation',
                      value: ordinance.source,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.25),
                        ),
                      ),
                      child: const Text(
                        _legalDisclaimer,
                        style: TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'If you observed this, submit a report in “My Reports” → New Report.',
                      style: TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrdinanceCardModel {
  final String imagePath;
  final String title;
  final String description;
  final List<String> prohibited;
  final String penalties;
  final String whereApplies;
  final String source;

  const _OrdinanceCardModel({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.prohibited,
    required this.penalties,
    required this.whereApplies,
    required this.source,
  });
}

class _BulletSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14.2, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    e,
                    style: const TextStyle(fontSize: 13.2, height: 1.35),
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

class _InfoSection extends StatelessWidget {
  final String title;
  final String value;

  const _InfoSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14.2, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 13.2, height: 1.35)),
      ],
    );
  }
}
