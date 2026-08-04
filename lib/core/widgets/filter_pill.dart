import 'package:flutter/material.dart';

import '../theme/vyra_style.dart';

/// A tappable filter chip used by the list screens (journal / habits / notes).
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.onClear,
    this.padding = const EdgeInsets.only(right: 8),
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onClear;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final contentColor = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Padding(
      padding: padding,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(style.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(style.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: contentColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (onClear != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(Icons.close, size: 14, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
