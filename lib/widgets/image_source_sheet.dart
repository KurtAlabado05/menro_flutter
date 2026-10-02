import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_tokens.dart';
import 'section_widgets.dart';

/// Bottom sheet asking whether to use the camera or the gallery.
Future<ImageSource?> showImageSourceSheet(
  BuildContext context, {
  String title = 'Add Photo',
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            SheetActionTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a Photo',
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            SheetActionTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}
