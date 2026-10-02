import 'package:flutter/material.dart';
import 'app_colors.dart';

class GradientUtils {
  /// Primary gradient background decoration
  static BoxDecoration primaryGradientDecoration({double radius = 16}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.primaryGradient,
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Success gradient background
  static BoxDecoration successGradientDecoration({double radius = 16}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.successGradient,
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Primary gradient shader for AppBar
  static LinearGradient primaryLinearGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: AppColors.primaryGradient,
    );
  }

  /// Accent gradient shader
  static LinearGradient accentLinearGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: AppColors.accentGradient,
    );
  }
}
