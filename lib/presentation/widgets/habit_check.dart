import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/habit.dart';
import '../../domain/services/habit_stats.dart';
import '../../application/habits/habit_providers.dart';

/// Animated check button showing whether a habit is done today.
class HabitCheck extends ConsumerWidget {
  const HabitCheck({
    super.key,
    required this.habit,
    required this.onChanged,
    this.size = 34,
  });

  final Habit habit;
  final VoidCallback onChanged;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final counts = ref.watch(habitCountsProvider(habit.id));
    final done = HabitStats.isDoneOn(habit, counts, DateTime.now());
    final color = Color(habit.color);

    return GestureDetector(
      onTap: onChanged,
      child: AnimatedScale(
        scale: done ? 1 : 0.9,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : scheme.surfaceContainerHigh,
            border: Border.all(
              color: done ? color : scheme.outlineVariant.withValues(alpha: 0.6),
              width: 1.4,
            ),
          ),
          child: Icon(
            done
                ? Icons.check
                : (habit.type == HabitType.good ? Icons.add : Icons.close),
            size: size * 0.55,
            color: done ? Colors.white : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
