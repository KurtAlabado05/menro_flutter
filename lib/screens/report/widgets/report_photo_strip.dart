import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../picked_image.dart';

class ReportPhotoStrip extends StatelessWidget {
  const ReportPhotoStrip({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final List<PickedImage> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool enabled;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == images.length) {
            return Semantics(
              button: true,
              label: 'Add photo',
              excludeSemantics: true,
              child: Material(
                color: AppColors.primary.fade(0.06),
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  onTap: enabled ? onAdd : null,
                  borderRadius: AppRadius.mdAll,
                  child: Container(
                    width: _size,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: AppColors.primary.fade(0.3)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final bytes = images[index].bytes;
          return SizedBox(
            width: _size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: bytes == null
                      ? const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.broken_image_outlined),
                        )
                      : Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          semanticLabel: 'Attached photo ${index + 1}',
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Remove photo ${index + 1}',
                    onPressed: enabled ? () => onRemove(index) : null,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
