import 'package:flutter/material.dart';

class AppBrandLogos extends StatelessWidget {
  const AppBrandLogos({super.key, this.size = 88, this.gap = 16});

  final double size;
  final double gap;

  static const ecoMapAsset = 'assets/images/ui/ecomap_logo_display.png';
  static const partnerAsset = 'assets/images/ui/baliwag_seal_display.png';

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _logo(ecoMapAsset, 'EcoMap logo'),
          SizedBox(width: gap),
          _logo(partnerAsset, 'MENRO partner, Baliwag city seal'),
        ],
    );
  }

  Widget _logo(String asset, String label) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(asset, fit: BoxFit.contain, semanticLabel: label),
    );
  }
}
