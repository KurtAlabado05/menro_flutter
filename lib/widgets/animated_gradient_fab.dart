import 'package:flutter/material.dart';
import '../core/constants/gradient_utils.dart';

class AnimatedGradientFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final bool mini;
  final Duration animationDuration;

  const AnimatedGradientFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.mini = false,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<AnimatedGradientFAB> createState() => _AnimatedGradientFABState();
}

class _AnimatedGradientFABState extends State<AnimatedGradientFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: RotationTransition(
          turns: _rotationAnimation,
          child: Container(
            decoration:
                GradientUtils.primaryGradientDecoration(radius: 30),
            child: FloatingActionButton(
              onPressed: null,
              backgroundColor: Colors.transparent,
              elevation: 0,
              tooltip: widget.tooltip,
              mini: widget.mini,
              shape: const CircleBorder(),
              child: Icon(widget.icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
