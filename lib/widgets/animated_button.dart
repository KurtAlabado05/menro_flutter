import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';
import '../core/constants/gradient_utils.dart';

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isLoading;
  final IconData? icon;
  final bool useGradient;
  final Duration animationDuration;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
    this.icon,
    this.useGradient = false,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final VoidCallback? handler = widget.isLoading ? null : widget.onPressed;
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: handler,
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: widget.useGradient && !widget.isOutlined
              ? Container(
                  decoration: GradientUtils.primaryGradientDecoration(radius: 8),
                  child: Center(child: _buildChild(Colors.white)),
                )
              : widget.isOutlined
                  ? OutlinedButton(
                      onPressed: handler,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.primary, width: 2),
                        shape: shape,
                      ),
                      child: _buildChild(AppColors.primary),
                    )
                  : ElevatedButton(
                      onPressed: handler,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.fade(0.6),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: shape,
                      ),
                      child: _buildChild(Colors.white),
                    ),
        ),
      ),
    );
  }

  Widget _buildChild(Color textColor) {
    if (widget.isLoading) {
      return Semantics(
        label: 'Loading',
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: textColor,
          ),
        ),
      );
    }

    final label = Text(
      widget.text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );

    if (widget.icon == null) return label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, color: textColor),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
  }
}
