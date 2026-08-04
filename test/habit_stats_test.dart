import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/utils/date_utils.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/services/habit_stats.dart';

Habit _goodHabit({int target = 1}) => Habit(
      name: 'Read',
      description: '',
      type: HabitType.good,
      color: 0xFF10B981,
      iconIndex: 0,
      targetPerDay: target,
      reminderEnabled: false,
      createdAt: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    );

Habit _badHabit() => Habit(
      name: 'No sugar',
      description: '',
      type: HabitType.bad,
      color: 0xFFEF4444,
      iconIndex: 0,
      targetPerDay: 1,
      reminderEnabled: false,
      createdAt: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    );

Map<String, int> _counts(Map<DateTime, int> raw) => {
      for (final e in raw.entries) AppDate.dayKey(e.key): e.value,
    };

void main() {
  final today = DateTime(2026, 8, 4);
  final yesterday = DateTime(2026, 8, 3);

  group('isDoneOn', () {
    test('good habit is done when count reaches target', () {
      final habit = _goodHabit();
      expect(HabitStats.isDoneOn(habit, {}, today), isFalse);
      expect(
        HabitStats.isDoneOn(habit, _counts({today: 1}), today),
        isTrue,
      );
    });

    test('good habit with target 2 needs 2 counts', () {
      final habit = _goodHabit(target: 2);
      expect(
        HabitStats.isDoneOn(habit, _counts({today: 1}), today),
        isFalse,
      );
      expect(
        HabitStats.isDoneOn(habit, _counts({today: 2}), today),
        isTrue,
      );
    });

    test('bad habit is done when count is zero (avoided)', () {
      final habit = _badHabit();
      expect(HabitStats.isDoneOn(habit, {}, today), isTrue);
      expect(
        HabitStats.isDoneOn(habit, _counts({today: 1}), today),
        isFalse,
      );
    });
  });

  group('currentStreak', () {
    test('no logs, good habit -> 0', () {
      expect(HabitStats.currentStreak(_goodHabit(), {}, today: today), 0);
    });

    test('two consecutive done days -> 2', () {
      final habit = _goodHabit();
      final counts = _counts({today: 1, yesterday: 1});
      expect(HabitStats.currentStreak(habit, counts, today: today), 2);
    });

    test('gap breaks the streak', () {
      final habit = _goodHabit();
      final counts = _counts({
        today: 1,
        DateTime(2026, 8, 1): 1,
      });
      expect(HabitStats.currentStreak(habit, counts, today: today), 1);
    });

    test('streak survives when today not done yet (counts from yesterday)', () {
      final habit = _goodHabit();
      final counts = _counts({
        yesterday: 1,
        DateTime(2026, 8, 2): 1,
      });
      expect(HabitStats.currentStreak(habit, counts, today: today), 2);
    });

    test('bad habit clean streak counts from creation date', () {
      final habit = _badHabit();
      // No logs: never did the bad behavior -> streak from creation.
      expect(HabitStats.currentStreak(habit, {}, today: today), 35);
    });
  });

  group('longestStreak', () {
    test('longest run of 3 wins over current run of 1', () {
      final habit = _goodHabit();
      final counts = _counts({
        today: 1,
        DateTime(2026, 7, 30): 1,
        DateTime(2026, 7, 29): 1,
        DateTime(2026, 7, 28): 1,
      });
      expect(HabitStats.longestStreak(habit, counts, today: today), 3);
    });
  });

  group('completion', () {
    test('50% over two days', () {
      final habit = _goodHabit();
      final counts = _counts({
        DateTime(2026, 8, 3): 1,
      });
      final start = DateTime(2026, 8, 3);
      final end = DateTime(2026, 8, 4);
      expect(HabitStats.completion(habit, counts, start, end), 0.5);
    });

    test('days before habit creation are not counted', () {
      final habit = _goodHabit();
      final counts = _counts({
        DateTime(2026, 7, 31): 1,
        DateTime(2026, 8, 4): 1,
      });
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 8, 4);
      // The period starts at creation (Jul 1): 35 days, 2 done.
      expect(HabitStats.completion(habit, counts, start, end), closeTo(2 / 35, 0.001));
    });
  });

  group('daysDone', () {
    test('counts only done days in range', () {
      final habit = _goodHabit();
      final counts = _counts({
        DateTime(2026, 8, 1): 1,
        DateTime(2026, 8, 2): 1,
        DateTime(2026, 8, 4): 1,
      });
      final done = HabitStats.daysDone(
        habit,
        counts,
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 4),
      );
      expect(done, 3);
    });
  });
}
