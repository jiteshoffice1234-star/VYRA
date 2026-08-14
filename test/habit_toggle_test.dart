import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/application/habits/habit_providers.dart';
import 'package:vyra/application/providers/app_providers.dart';
import 'package:vyra/core/database/app_database.dart';
import 'package:vyra/data/repositories/habit_repository.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/services/habit_stats.dart';

Habit _good({int target = 1}) => Habit(
      id: 1,
      name: 'Read',
      description: '',
      type: HabitType.good,
      color: 0xFF10B981,
      iconIndex: 0,
      targetPerDay: target,
      reminderEnabled: false,
      createdAt: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    );

Habit _bad() => Habit(
      id: 2,
      name: 'No sugar',
      description: '',
      type: HabitType.bad,
      color: 0xFFF43F5E,
      iconIndex: 0,
      targetPerDay: 1,
      reminderEnabled: false,
      createdAt: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    );

void main() {
  final day = DateTime(2026, 8, 3);
  final dayKey = '2026-08-03';

  group('HabitStats.toggleCount', () {
    test('good habit: not done -> target, done -> 0', () {
      expect(HabitStats.toggleCount(_good(target: 2), {}, day), 2);
      expect(
        HabitStats.toggleCount(_good(target: 2), {dayKey: 2}, day),
        0,
      );
      // A partial count is not done, so toggling marks the day complete.
      expect(
        HabitStats.toggleCount(_good(target: 2), {dayKey: 1}, day),
        2,
      );
    });

    test('bad habit: avoided (absent/0) -> 1, slipped (1) -> 0', () {
      expect(HabitStats.toggleCount(_bad(), {}, day), 1);
      expect(HabitStats.toggleCount(_bad(), {dayKey: 0}, day), 1);
      expect(HabitStats.toggleCount(_bad(), {dayKey: 1}, day), 0);
    });
  });

  group('HabitsNotifier.toggleDay', () {
    test('logs, undoes and rejects future days via the real pipeline', () async {
      final db = await AppDatabase.openInMemory();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);

      final repo = HabitRepository(db.db);
      final id = await repo.insert(_good(target: 2));
      final habit = (await container.read(habitsProvider.future)).single;
      final notifier = container.read(habitsProvider.notifier);

      // Not done -> writes the target count.
      await notifier.toggleDay(habit, day);
      expect((await repo.countsForHabit(id))[dayKey], 2);

      // Toggling again undoes the day.
      await notifier.toggleDay(habit, day);
      expect((await repo.countsForHabit(id))[dayKey], 0);

      // Future days are rejected without writing anything.
      final future = DateTime(2026, 8, 20);
      await notifier.toggleDay(habit, future);
      final counts = await repo.countsForHabit(id);
      expect(counts.containsKey('2026-08-20'), isFalse);
    });

    test('today (timestamped) is accepted', () async {
      final db = await AppDatabase.openInMemory();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);

      final repo = HabitRepository(db.db);
      final id = await repo.insert(_good());
      final habit = (await container.read(habitsProvider.future)).single;
      final notifier = container.read(habitsProvider.notifier);

      final now = DateTime.now();
      await notifier.toggleDay(habit, now);
      final counts = await repo.countsForHabit(id);
      expect(counts.values.single, 1);
    });
  });
}
