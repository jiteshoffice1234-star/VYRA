import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/utils/date_utils.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/models/journal_entry.dart';
import 'package:vyra/domain/models/mood.dart';
import 'package:vyra/domain/services/week_review.dart';

JournalEntry _journal({
  int id = 1,
  DateTime? day,
  String title = 'Entry',
  Mood mood = Mood.happy,
}) =>
    JournalEntry(
      id: id,
      title: title,
      content: 'Body text',
      mood: mood,
      isFavorite: false,
      entryDate: day ?? AppDate.today(),
      createdAt: 0,
      updatedAt: 0,
    );

Habit _habit({
  int id = 20,
  String name = 'Read',
  DateTime? created,
  HabitType type = HabitType.good,
}) =>
    Habit(
      id: id,
      name: name,
      description: '',
      type: type,
      color: 0xFF10B981,
      iconIndex: 0,
      targetPerDay: 1,
      reminderEnabled: false,
      archived: false,
      createdAt: (created ?? DateTime(2026, 7, 1)).millisecondsSinceEpoch,
    );

void main() {
  final today = AppDate.today();
  final d1 = AppDate.addDays(today, -1);
  final d6 = AppDate.addDays(today, -6);
  final d8 = AppDate.addDays(today, -8); // outside the week window

  group('WeekReviewService.build', () {
    test('week completion averages habit rates over the trailing 7 days', () {
      final review = WeekReviewService.build(
        journals: [],
        habits: [_habit(id: 20, name: 'Read')],
        counts: {
          20: {AppDate.dayKey(today): 1},
        },
      );
      expect(review.totalHabits, 1);
      expect(review.weekCompletion, closeTo(1 / 7, 0.001));
      expect(review.doneByDay, hasLength(7));
      expect(review.doneByDay[6], 1); // today
    });

    test('best day is the busiest day inside the week window', () {
      final review = WeekReviewService.build(
        journals: [],
        habits: [
          _habit(id: 20, name: 'Read'),
          _habit(id: 21, name: 'Run'),
        ],
        counts: {
          20: {AppDate.dayKey(d1): 1, AppDate.dayKey(today): 1},
          21: {AppDate.dayKey(d1): 1},
        },
      );
      expect(review.bestDayCount, 2);
      expect(AppDate.isSameDay(review.bestDay!, d1), isTrue);
    });

    test('mood trend is scoped to this week only', () {
      final review = WeekReviewService.build(
        journals: [
          _journal(id: 1, day: today, mood: Mood.happy),
          _journal(id: 2, day: d1, mood: Mood.calm),
          _journal(id: 3, day: d8, mood: Mood.angry), // outside the week
        ],
        habits: [],
        counts: const {},
      );
      expect(review.journalCount, 2);
      expect(review.moodStats, hasLength(2));
      expect(review.topMood, Mood.happy);
    });

    test('streak delta compares the streak now to a week ago', () {
      final review = WeekReviewService.build(
        journals: [],
        habits: [_habit(id: 20, name: 'Read')],
        counts: {
          20: {
            AppDate.dayKey(today): 1,
            AppDate.dayKey(d1): 1,
          },
        },
      );
      expect(review.currentStreak, 2);
      expect(review.streakWeekAgo, 0);
      expect(review.streakDelta, 2);
    });

    test('on-track habits are those at 100% for the week', () {
      final review = WeekReviewService.build(
        journals: [],
        habits: [
          _habit(id: 20, name: 'Read'),
          _habit(id: 21, name: 'Run'),
        ],
        counts: {
          20: {AppDate.dayKey(d1): 1}, // 1/7
          21: {
            AppDate.dayKey(d6): 1,
            AppDate.dayKey(d1): 1,
            AppDate.dayKey(today): 1,
          }, // 3/7
        },
      );
      expect(review.onTrackHabits, 0);
      expect(review.habitStats, hasLength(2));
    });

    test('summary mentions completion, best day and top mood', () {
      final review = WeekReviewService.build(
        journals: [_journal(id: 1, day: today, mood: Mood.happy)],
        habits: [_habit(id: 20, name: 'Read')],
        counts: {
          20: {AppDate.dayKey(today): 1},
        },
      );
      final s = review.summary;
      expect(s, contains('%'));
      expect(s, contains('best day'));
      expect(s, contains('Happy'));
      expect(s, contains('journal'));
    });

    test('summary reports no activity when the week is empty', () {
      final review = WeekReviewService.build(
        journals: [_journal(id: 1, day: d8, mood: Mood.happy)],
        habits: [_habit(id: 20)],
        counts: const {},
      );
      expect(review.summary, contains('No activity'));
    });
  });
}
