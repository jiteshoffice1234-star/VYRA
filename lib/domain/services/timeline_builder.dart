import '../../core/utils/date_utils.dart';
import '../models/day_timeline.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/note.dart';
import 'habit_stats.dart';

/// Pure aggregation of journal / note / habit data into the daily timeline.
///
/// Kept free of Flutter and database concerns so it can be unit tested and
/// reused by any future UI (export, widgets, AI summaries).
class TimelineBuilder {
  TimelineBuilder._();

  /// Merges all sources into day summaries, newest first.
  ///
  /// [countsGrouped] maps habit id → (dayKey → count), the same shape produced
  /// by `HabitRepository.countsGrouped()`. Habits that were completed on a day
  /// appear even if they have since been archived, so history stays truthful.
  static List<DayTimeline> build({
    required List<JournalEntry> journals,
    required List<Note> notes,
    required List<Habit> habits,
    required Map<int, Map<String, int>> countsGrouped,
  }) {
    final habitById = {for (final h in habits) h.id: h};

    // Notes keyed by the day they were last edited (a note is "of" the day it
    // was touched), newest first.
    final notesByDay = <String, List<Note>>{};
    for (final note in notes) {
      final key = AppDate.dayKey(
        AppDate.startOfDay(DateTime.fromMillisecondsSinceEpoch(note.updatedAt)),
      );
      notesByDay.putIfAbsent(key, () => []).add(note);
    }
    for (final list in notesByDay.values) {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    // Journals keyed by entry date (at most one per day).
    final journalByDay = <String, JournalEntry>{
      for (final e in journals)
        AppDate.dayKey(AppDate.startOfDay(e.entryDate)): e,
    };

    // Done habits per day, from every habit that has any logs. Archived
    // habits with historical logs are included via their ids.
    final doneHabitsByDay = <String, List<Habit>>{};
    for (final entry in countsGrouped.entries) {
      final habit = habitById[entry.key];
      if (habit == null) continue;
      // Key-based check avoids a date round-trip per log row; with years of
      // habit history this loop dominates timeline construction cost.
      for (final dayKey in entry.value.keys) {
        if (!HabitStats.isDoneOnKey(habit, entry.value, dayKey)) continue;
        doneHabitsByDay.putIfAbsent(dayKey, () => []).add(habit);
      }
    }

    // Union of all activity days, newest first.
    final dayKeys = <String>{
      ...notesByDay.keys,
      ...journalByDay.keys,
      ...doneHabitsByDay.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return [
      for (final key in dayKeys)
        DayTimeline(
          date: AppDate.parseDayKey(key),
          journal: journalByDay[key],
          notes: notesByDay[key] ?? const [],
          doneHabits: doneHabitsByDay[key] ?? const [],
        ),
    ];
  }
}
