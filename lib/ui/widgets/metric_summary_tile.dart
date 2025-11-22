import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'billing_card.dart';
import 'status_pill.dart';

class MetricSummaryTile extends StatelessWidget {
  const MetricSummaryTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailing,
    this.statusVariant,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Widget? trailing;
  final StatusPillVariant? statusVariant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();

    return BillingCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.92),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors?.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: trailing,
                ),
            ],
          ),
          if (subtitle != null || statusVariant != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.84),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (statusVariant != null) ...[
                  const SizedBox(width: 12),
                  StatusPill(
                    label: statusVariant == StatusPillVariant.success
                        ? 'On track'
                        : statusVariant == StatusPillVariant.warning
                        ? 'Needs attention'
                        : statusVariant == StatusPillVariant.danger
                        ? 'Overdue'
                        : 'Active',
                    variant: statusVariant!,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
