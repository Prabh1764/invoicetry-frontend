import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum StatusPillVariant { neutral, success, warning, danger }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.variant = StatusPillVariant.neutral,
    this.leading,
    this.trailing,
  });

  final String label;
  final StatusPillVariant variant;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();

    Color background;
    Color foreground;

    switch (variant) {
      case StatusPillVariant.success:
        background = (colors?.success ?? const Color(0xFF0FA47F)).withOpacity(
          .1,
        );
        foreground = colors?.success ?? const Color(0xFF0FA47F);
        break;
      case StatusPillVariant.warning:
        background = (colors?.warning ?? const Color(0xFFF59E0B)).withOpacity(
          .12,
        );
        foreground = colors?.warning ?? const Color(0xFFF59E0B);
        break;
      case StatusPillVariant.danger:
        background = (colors?.danger ?? const Color(0xFFEF4444)).withOpacity(
          .12,
        );
        foreground = colors?.danger ?? const Color(0xFFEF4444);
        break;
      case StatusPillVariant.neutral:
      default:
        background = colors?.pillBackground ?? const Color(0xFFE8EDF7);
        foreground = colors?.pillForeground ?? theme.colorScheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(size: 14, color: foreground),
              child: leading!,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              letterSpacing: 0.6,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            IconTheme.merge(
              data: IconThemeData(size: 14, color: foreground),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
