import 'package:flutter/material.dart';

import '../../domain/models/mood.dart';
import '../theme/mood_colors.dart';
import '../theme/vyra_style.dart';

/// Horizontal mood picker used in the journal editor.
class MoodSelector extends StatelessWidget {
  const MoodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Mood selected;
  final ValueChanged<Mood> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final mood in Mood.values)
          _MoodButton(
            mood: mood,
            selected: mood == selected,
            onTap: () => onChanged(mood),
            scheme: scheme,
          ),
      ],
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.mood,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = mood.color;
    final style = VyraStyle.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(style.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(style.radius),
          border: Border.all(
            color: selected ? color : scheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1,
              duration: const Duration(milliseconds: 200),
              child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 4),
            Text(
              mood.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? color : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
