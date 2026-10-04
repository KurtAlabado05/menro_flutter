import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';
import '../core/constants/gradient_utils.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isLoading;
  final IconData? icon;
  final bool useGradient;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
    this.icon,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handler = isLoading ? null : onPressed;
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);

    if (useGradient && !isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: Container(
          decoration: GradientUtils.primaryGradientDecoration(radius: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: handler,
              borderRadius: AppRadius.mdAll,
              child: Center(child: _buildChild(Colors.white)),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: isOutlined
          ? OutlinedButton(
              onPressed: handler,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 2),
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
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return Semantics(
        label: 'Loading',
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
        ),
      );
    }

    final label = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );

    if (icon == null) return label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: textColor),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
  }
}
