import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum AppMessageType { success, error, info, warning }

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppMessageType type = AppMessageType.info,
  SnackBarAction? action,
}) {
  final (color, icon) = switch (type) {
    AppMessageType.success => (AppColors.primary, Icons.check_circle_outline),
    AppMessageType.error => (const Color(0xFFC62828), Icons.error_outline),
    AppMessageType.warning => (const Color(0xFFEF6C00), Icons.warning_amber_rounded),
    AppMessageType.info => (AppColors.textDark, Icons.info_outline),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        action: action,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
