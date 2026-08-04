import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/utils/date_utils.dart';
import 'package:vyra/domain/models/category.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/models/journal_entry.dart';
import 'package:vyra/domain/models/mood.dart';
import 'package:vyra/domain/models/note.dart';
import 'package:vyra/domain/services/analytics_service.dart';

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

Note _note({int id = 10, String title = 'Note'}) => Note(
      id: id,
      title: title,
      content: 'x',
      type: NoteType.text,
      color: 0xFFF59E0B,
      isPinned: false,
      isFavorite: false,
      createdAt: 0,
      updatedAt: 0,
    );

Habit _habit({
  int id = 20,
  String name = 'Read',
  DateTime? created,
  bool archived = false,
  int? categoryId,
}) =>
    Habit(
      id: id,
      name: name,
      description: '',
      type: HabitType.good,
      color: 0xFF10B981,
      iconIndex: 0,
      categoryId: categoryId,
      targetPerDay: 1,
      reminderEnabled: false,
      archived: archived,
      createdAt: (created ?? DateTime(2026, 7, 1)).millisecondsSinceEpoch,
    );

Map<int, Map<String, int>> _counts(Map<int, Map<String, int>> raw) => raw;

void main() {
  final today = AppDate.today();
  final d1 = AppDate.addDays(today, -1);
  final d2 = AppDate.addDays(today, -2);

  group('AnalyticsService.compute', () {
    test('mood stats aggregate by mood and sort by count', () {
      final data = AnalyticsService.compute(
        journals: [
          _journal(id: 1, day: today, mood: Mood.happy),
          _journal(id: 2, day: d1, mood: Mood.calm),
          _journal(id: 3, day: d2, mood: Mood.happy),
        ],
        notes: [],
        habits: [],
        categories: [],
        counts: const {},
      );
      expect(data.totalJournals, 3);
      expect(data.moodStats.first.mood, Mood.happy);
      expect(data.moodStats.first.count, 2);
      expect(data.moodStats, hasLength(2));
    });

    test('best day is the day with most habits done', () {
      final data = AnalyticsService.compute(
        journals: [],
        notes: [],
        habits: [
          _habit(id: 20, name: 'Read'),
          _habit(id: 21, name: 'Run'),
        ],
        categories: [],
        counts: _counts({
          20: {AppDate.dayKey(d1): 1, AppDate.dayKey(today): 1},
          21: {AppDate.dayKey(d1): 1},
        }),
      );
      expect(data.bestDayCount, 2);
      expect(AppDate.isSameDay(data.bestDay!, d1), isTrue);
    });

    test('longest streak is the max across habits', () {
      final data = AnalyticsService.compute(
        journals: [],
        notes: [],
        habits: [
          _habit(id: 20, name: 'Read'),
          _habit(id: 21, name: 'Run'),
        ],
        categories: [],
        counts: _counts({
          20: {
            AppDate.dayKey(d1): 1,
            AppDate.dayKey(d2): 1,
          },
          21: {
            AppDate.dayKey(today): 1,
          },
        }),
      );
      expect(data.bestStreak, 2);
      expect(data.currentStreak, greaterThanOrEqualTo(1));
    });

    test('journal frequency buckets by month', () {
      final data = AnalyticsService.compute(
        journals: [
          _journal(id: 1, day: DateTime(2026, 7, 5)),
          _journal(id: 2, day: DateTime(2026, 7, 20)),
          _journal(id: 3, day: DateTime(2026, 8, 1)),
        ],
        notes: [],
        habits: [],
        categories: [],
        counts: const {},
      );
      expect(data.journalFrequency, hasLength(2));
      expect(data.journalFrequency[0].month.month, 7);
      expect(data.journalFrequency[0].count, 2);
      expect(data.journalFrequency[1].month.month, 8);
      expect(data.journalFrequency[1].count, 1);
    });

    test('category stats split habits and notes', () {
      final data = AnalyticsService.compute(
        journals: [],
        notes: [_note(id: 1), _note(id: 2)],
        habits: [_habit(id: 3, categoryId: 7)],
        categories: [
          const Category(id: 7, name: 'Health', color: 0xFF10B981, kind: CategoryKind.habit),
        ],
        counts: const {},
      );
      expect(data.noteCategoryStats.single.name, 'Uncategorized');
      expect(data.noteCategoryStats.single.count, 2);
      expect(data.habitCategoryStats.single.name, 'Health');
      expect(data.habitCategoryStats.single.count, 1);
    });

    test('recent activity merges journals, notes and habit completions', () {
      final data = AnalyticsService.compute(
        journals: [_journal(id: 1, day: today)],
        notes: [_note(id: 2)],
        habits: [_habit(id: 3, name: 'Read')],
        categories: [],
        counts: _counts({
          3: {AppDate.dayKey(d1): 1},
        }),
      );
      expect(data.recentActivity, isNotEmpty);
      final titles = data.recentActivity.map((a) => a.title).toSet();
      expect(titles, contains('Journaled'));
      expect(titles, contains('Saved note'));
      expect(titles, contains('Habit completed'));
    });
  });

  group('completionForWindow', () {
    test('counts done and total days within the window', () {
      final habits = [_habit(id: 20, name: 'Read')];
      final counts = _counts({
        20: {AppDate.dayKey(d1): 1},
      });
      final data = AnalyticsService.compute(
        journals: [],
        notes: [],
        habits: habits,
        categories: [],
        counts: counts,
      );
      final stats = data.completionForWindow(habits, counts, 7);
      expect(stats, hasLength(1));
      expect(stats.single.doneDays, 1);
      expect(stats.single.totalDays, 7);
      expect(stats.single.rate, closeTo(1 / 7, 0.001));
    });
  });
}
