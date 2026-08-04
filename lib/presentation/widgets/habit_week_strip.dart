import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/habit.dart';
import '../../domain/services/habit_stats.dart';

/// Last 7 days (ending today) as day cells with done/not-done states.
class HabitWeekStrip extends StatelessWidget {
  const HabitWeekStrip({
    super.key,
    required this.habit,
    required this.counts,
  });

  final Habit habit;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(habit.color);
    final today = AppDate.today();
    final start = AppDate.addDays(today, -6);

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              day: AppDate.addDays(start, i),
              done: HabitStats.isDoneOn(habit, counts, AppDate.addDays(start, i)),
              color: color,
              scheme: scheme,
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.done,
    required this.color,
    required this.scheme,
  });

  final DateTime day;
  final bool done;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isToday = AppDate.isToday(day);
    return Column(
      children: [
        Text(
          AppDate.weekdayLetter(day),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          '${day.day}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : Colors.transparent,
            border: done ? null : Border.all(color: scheme.outlineVariant),
          ),
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}
