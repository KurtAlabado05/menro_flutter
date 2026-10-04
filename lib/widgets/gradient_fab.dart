import 'package:flutter/material.dart';
import '../core/constants/gradient_utils.dart';

class GradientFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final bool mini;

  const GradientFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GradientUtils.primaryGradientDecoration(radius: 30),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        tooltip: tooltip,
        mini: mini,
        shape: const CircleBorder(),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
