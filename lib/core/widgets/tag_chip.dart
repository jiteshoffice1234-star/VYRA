import 'package:flutter/material.dart';

import '../theme/vyra_style.dart';

/// Small tag pill, optionally deletable.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.onTap,
    this.onDeleted,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final bg = selected ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(style.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(style.radius),
          border: style.boxBorder ??
              Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
              ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag, size: 13, color: fg.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
            if (onDeleted != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close, size: 14, color: fg.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
