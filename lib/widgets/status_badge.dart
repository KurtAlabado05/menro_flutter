import 'package:flutter/material.dart';
import '../core/constants/status_config.dart';

/// A widget that displays a status badge with consistent styling.
/// Uses StatusConfig for centralized status management.
class StatusBadge extends StatelessWidget {
  final String? status;
  final bool showIcon;
  final double? fontSize;

  const StatusBadge({
    super.key,
    this.status,
    this.showIcon = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final config = StatusConfig.fromStatus(status);
    final color = config.color;
    final label = config.label;
    final hsl = HSLColor.fromColor(color);
    final textColor = hsl
        .withLightness((hsl.lightness * 0.7).clamp(0.0, 0.35))
        .toColor();

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showIcon ? 8 : 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon)
              Icon(
                config.icon,
                size: fontSize != null ? fontSize! - 2 : 13,
                color: textColor,
              ),
            if (showIcon) const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: textColor,
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget that displays a status badge in a compact pill style.
class StatusPill extends StatelessWidget {
  final String? status;
  final bool small;

  const StatusPill({super.key, this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final config = StatusConfig.fromStatus(status);
    final color = config.color;
    final label = config.label;
    final fontSize = small ? 10.0 : 12.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A widget that displays a status dot with optional label.
class StatusDot extends StatelessWidget {
  final String? status;
  final double size;
  final bool showLabel;

  const StatusDot({
    super.key,
    this.status,
    this.size = 10,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = StatusConfig.fromStatus(status);
    final color = config.color;

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
