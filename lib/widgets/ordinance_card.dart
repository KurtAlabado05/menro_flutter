import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class MenroOrdinanceCarousel extends StatefulWidget {
  const MenroOrdinanceCarousel({super.key});

  @override
  State<MenroOrdinanceCarousel> createState() => _MenroOrdinanceCarouselState();
}

class _MenroOrdinanceCarouselState extends State<MenroOrdinanceCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _carouselTimer;

  // Complete list matching the actual MENRO Baliuag ordinance graphics
  final List<Map<String, String>> _ordinances = [
    {
      'image': 'assets/images/ordinances/no_illegal_dumping.png',
      'title': 'No Illegal Dumping',
      'subtitle':
          'Strictly prohibited under environmental sanitation policies.',
    },
    {
      'image': 'assets/images/ordinances/no_burning_of_waste.png',
      'title': 'No Burning of Waste',
      'subtitle':
          'Open-air burning compromises atmospheric health regulations.',
    },
    {
      'image': 'assets/images/ordinances/bawal_magtapon_sa_mga_ilog.png',
      'title': 'Proteksyon sa mga Ilog',
      'subtitle': 'Bawal magtapon ng anumang bagay sa mga ilog at estero.',
    },
    {
      'image': 'assets/images/ordinances/no_smoking.png',
      'title': 'No Smoking Area',
      'subtitle':
          'Compliance mandates designated community clean air protection zones.',
    },
    {
      'image': 'assets/images/ordinances/bawal_magtapon_ng_likido.png',
      'title': 'Bawal Magtapon ng Likido',
      'subtitle':
          'Prohibits discarding dangerous chemical liquids or contaminants into drains.',
    },
    {
      'image': 'assets/images/ordinances/bawal_magtapon_ng_basura.jpg',
      'title': 'Bawal Magtapon ng Basura',
      'subtitle': 'Keep our public spaces clean. Dispose of garbage properly.',
    },
    {
      'image': 'assets/images/ordinances/kung_hindi_mo_kayang_linisin.png',
      'title': 'Disiplina sa Kapaligiran',
      'subtitle':
          'Kung hindi mo kayang linisin ang kapaligiran, huwag mo nang dumiha pa.',
    },
    {
      'image': 'assets/images/ordinances/follow_environmental_rules.png',
      'title': 'Follow Environmental Rules',
      'subtitle':
          'Let us work together to keep Baliuag sustainable and eco-friendly.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Dynamic slide rotation setup
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _ordinances.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Standard spacing layout token
            children: [
              const Text(
                'MENRO Environmental Ordinances',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Official Baliuag Guidelines',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 165,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _ordinances.length,
            itemBuilder: (context, index) {
              final item = _ordinances[index];
              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Graphic display presentation surface
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: Colors.grey.shade100,
                        height: double.infinity,
                        child: Image.asset(
                          item['image']!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                    ),
                    // Descriptive summary labels context
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['title']!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['subtitle']!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Tracking indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_ordinances.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              height: 5,
              width: _currentPage == index ? 14 : 5,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? Colors.green
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
