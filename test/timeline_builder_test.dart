import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/utils/date_utils.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/models/journal_entry.dart';
import 'package:vyra/domain/models/mood.dart';
import 'package:vyra/domain/models/note.dart';
import 'package:vyra/domain/services/timeline_builder.dart';

const _dayA = '2026-08-04';
const _dayB = '2026-08-03';
const _dayC = '2026-08-01';

JournalEntry _journal({
  int id = 1,
  String day = _dayA,
  String title = 'Morning run',
  Mood mood = Mood.happy,
}) =>
    JournalEntry(
      id: id,
      title: title,
      content: 'A great run in the park.',
      mood: mood,
      isFavorite: false,
      entryDate: AppDate.parseDayKey(day),
      createdAt: 0,
      updatedAt: 0,
    );

Note _note({
  int id = 10,
  String day = _dayA,
  String title = 'Groceries',
}) =>
    Note(
      id: id,
      title: title,
      content: 'Milk, eggs, bread',
      type: NoteType.text,
      color: 0xFFF59E0B,
      isPinned: false,
      isFavorite: false,
      createdAt: 0,
      updatedAt: DateTime.parse(day).millisecondsSinceEpoch,
    );

Habit _habit({
  int id = 20,
  String name = 'Read',
  HabitType type = HabitType.good,
  int target = 1,
  bool archived = false,
}) =>
    Habit(
      id: id,
      name: name,
      description: '',
      type: type,
      color: 0xFF10B981,
      iconIndex: 0,
      targetPerDay: target,
      reminderEnabled: false,
      archived: archived,
      createdAt: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    );

Map<int, Map<String, int>> _counts(Map<int, Map<String, int>> raw) => raw;

void main() {
  group('TimelineBuilder', () {
    test('sorts days newest first and attaches journal, notes and habits', () {
      final timeline = TimelineBuilder.build(
        journals: [
          _journal(id: 1, day: _dayA),
          _journal(id: 2, day: _dayC, title: 'Weekend'),
        ],
        notes: [_note(id: 10, day: _dayB, title: 'Idea')],
        habits: [_habit()],
        countsGrouped: _counts({
          20: {_dayA: 1},
        }),
      );

      expect(timeline, hasLength(3));
      expect(AppDate.dayKey(timeline[0].date), _dayA);
      expect(AppDate.dayKey(timeline[1].date), _dayB);
      expect(AppDate.dayKey(timeline[2].date), _dayC);

      // Day A: journal + done habit, no notes.
      expect(timeline[0].journal?.title, 'Morning run');
      expect(timeline[0].doneHabits.single.name, 'Read');
      expect(timeline[0].notes, isEmpty);

      // Day B: note only.
      expect(timeline[1].journal, isNull);
      expect(timeline[1].notes.single.title, 'Idea');
      expect(timeline[1].doneHabits, isEmpty);

      // Day C: journal only.
      expect(timeline[2].journal?.title, 'Weekend');
    });

    test('days without any activity are not emitted', () {
      final timeline = TimelineBuilder.build(
        journals: [_journal(day: _dayA)],
        notes: [_note(day: _dayB)],
        habits: [_habit()],
        countsGrouped: _counts({
          20: {_dayA: 1},
        }),
      );
      // _dayC is in between but has no activity: it must not appear.
      final keys = timeline.map((d) => AppDate.dayKey(d.date)).toList();
      expect(keys, [_dayA, _dayB]);
    });

    test('an unfulfilled target does not mark a day done', () {
      final timeline = TimelineBuilder.build(
        journals: [],
        notes: [],
        habits: [_habit(target: 2)],
        countsGrouped: _counts({
          20: {_dayA: 1},
        }),
      );
      expect(timeline, isEmpty);
    });

    test('bad habit days count when the behavior was avoided', () {
      final timeline = TimelineBuilder.build(
        journals: [],
        notes: [],
        habits: [_habit(type: HabitType.bad, name: 'No sugar')],
        countsGrouped: _counts({
          20: {_dayA: 0},
        }),
      );
      expect(timeline, hasLength(1));
      expect(timeline.single.doneHabits.single.name, 'No sugar');
    });

    test('archived habits with history still appear on old days', () {
      final timeline = TimelineBuilder.build(
        journals: [],
        notes: [],
        habits: [_habit(id: 20, archived: true)],
        countsGrouped: _counts({
          20: {_dayA: 1},
        }),
      );
      expect(timeline, hasLength(1));
      expect(timeline.single.doneHabits.single.name, 'Read');
    });
  });

  group('quickSummary', () {
    test('combines journal, habits and notes into one line', () {
      final timeline = TimelineBuilder.build(
        journals: [_journal(day: _dayA)],
        notes: [_note(day: _dayA)],
        habits: [_habit()],
        countsGrouped: _counts({
          20: {_dayA: 1},
        }),
      );
      final summary = timeline.single.quickSummary;
      expect(summary, contains('Happy'));
      expect(summary, contains('1 habit done'));
      expect(summary, contains('1 note'));
    });

    test('journal only summary starts with the mood emoji', () {
      final timeline = TimelineBuilder.build(
        journals: [_journal(day: _dayA, mood: Mood.calm)],
        notes: [],
        habits: [],
        countsGrouped: const {},
      );
      expect(timeline.single.quickSummary, '😌 Calm');
    });
  });
}
