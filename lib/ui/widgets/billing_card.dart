import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A premium-looking card with consistent padding, rounded corners, and shadow.
class BillingCard extends StatelessWidget {
  const BillingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BillingColors>();
    final resolvedRadius = borderRadius ?? BorderRadius.circular(24);

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors?.surface ?? Colors.white,
        borderRadius: resolvedRadius,
        border: Border.fromBorderSide(
          border ??
              BorderSide(
                color: colors?.border ?? const Color(0xFFE5E7EB),
                width: 1,
              ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors?.shadowColor.withOpacity(1) ?? Colors.black12,
            offset: const Offset(0, 12),
            blurRadius: 32,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return cardContent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: resolvedRadius,
        onTap: onTap,
        child: cardContent,
      ),
    );
  }
}
