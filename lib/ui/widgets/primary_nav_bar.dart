import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PrimaryNavDestination {
  const PrimaryNavDestination({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

class PrimaryNavBar extends StatelessWidget {
  const PrimaryNavBar({super.key, required this.destinations});

  final List<PrimaryNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BillingColors>();
    final spacing = theme.extension<BillingSpacing>();

    return Container(
      decoration: BoxDecoration(
        color: colors?.surface ?? Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colors?.border ?? Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (colors?.shadowColor ?? Colors.black12).withOpacity(.2),
            offset: const Offset(0, -4),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: destinations
            .map(
              (destination) => Expanded(
                child: _NavItem(
                  destination: destination,
                  colors: colors,
                  spacing: spacing,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.colors,
    required this.spacing,
  });

  final PrimaryNavDestination destination;
  final BillingColors? colors;
  final BillingSpacing? spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = destination.selected;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor =
        colors?.textMuted ?? theme.colorScheme.onSurface.withOpacity(.6);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: destination.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 12 : 8,
          vertical: selected ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: selected 
              ? activeColor.withOpacity(.12) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? Border.all(
                  color: activeColor.withOpacity(.3),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(selected ? 6 : 4),
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withOpacity(.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                destination.icon,
                size: selected ? 24 : 22,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
            SizedBox(height: spacing?.xs ?? 4),
            Flexible(
              child: Text(
                destination.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: selected ? 11 : 10,
                  color: selected ? activeColor : inactiveColor,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
