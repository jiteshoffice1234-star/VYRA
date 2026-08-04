import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/list_utils.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/note.dart';
import '../../domain/services/habit_stats.dart';
import '../habits/habit_providers.dart';
import '../journal/journal_providers.dart';
import '../notes/note_providers.dart';
import '../providers/app_providers.dart';

/// Everything the home screen needs, computed from the source list providers
/// so it refreshes automatically whenever journals / habits / notes change.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final journals = await ref.watch(journalListProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final notes = await ref.watch(notesProvider.future);
  final journalRepo = await ref.watch(journalRepositoryProvider.future);

  final counts = await ref.watch(habitCountsMapProvider.future);
  final journalDays = await journalRepo.allJournalDays();

  final now = DateTime.now();
  final today = AppDate.today();
  final weekStart = AppDate.addDays(today, -6);
  final monthStart = DateTime(now.year, now.month, 1);

  var bestCurrentStreak = 0;
  var bestLongestStreak = 0;
  var todayDone = 0;
  var weeklySum = 0.0;
  var monthlySum = 0.0;
  final weekBars = List<double>.filled(7, 0);

  // Week day keys computed once up front so per-habit checks never re-format.
  final weekKeys = [
    for (var i = 0; i < 7; i++) AppDate.dayKey(AppDate.addDays(weekStart, i)),
  ];

  for (final habit in habits) {
    final c = counts[habit.id] ?? const <String, int>{};
    final current = HabitStats.currentStreak(habit, c);
    final longest = HabitStats.longestStreak(habit, c);
    if (current > bestCurrentStreak) bestCurrentStreak = current;
    if (longest > bestLongestStreak) bestLongestStreak = longest;
    if (HabitStats.isDoneOn(habit, c, today)) todayDone++;
    weeklySum += HabitStats.completion(habit, c, weekStart, today);
    monthlySum += HabitStats.completion(habit, c, monthStart, today);
    for (var i = 0; i < 7; i++) {
      if (HabitStats.isDoneOnKey(habit, c, weekKeys[i])) weekBars[i] += 1;
    }
  }

  if (habits.isNotEmpty) {
    for (var i = 0; i < 7; i++) {
      weekBars[i] = weekBars[i] / habits.length;
    }
  }

  // Calendar dots: days this month with at least one done habit. Day keys
  // are computed once up front so the per-habit check never re-formats a date.
  final habitDayKeys = <String>{};
  final daysInMonth = AppDate.daysInMonth(now);
  final monthKeys = [
    for (var d = 1; d <= daysInMonth; d++) AppDate.dayKey(DateTime(now.year, now.month, d)),
  ];
  for (final key in monthKeys) {
    final anyDone = habits.any(
      (h) => HabitStats.isDoneOnKey(h, counts[h.id] ?? const <String, int>{}, key),
    );
    if (anyDone) habitDayKeys.add(key);
  }

  final recentNotes = [...notes]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  // Today's entry, if any (drives the "Today's journal" status card).
  final todayJournal =
      journals.firstWhereOrNull((e) => AppDate.isSameDay(e.entryDate, today));

  return DashboardData(
    bestCurrentStreak: bestCurrentStreak,
    bestLongestStreak: bestLongestStreak,
    todayDone: todayDone,
    todayTotal: habits.length,
    journalCount: journals.length,
    noteCount: notes.length,
    weeklyProgress: habits.isEmpty ? 0 : weeklySum / habits.length,
    monthlyProgress: habits.isEmpty ? 0 : monthlySum / habits.length,
    weekBars: weekBars,
    journalDayKeys: journalDays,
    habitDayKeys: habitDayKeys,
    todayHabits: habits,
    latestJournal: journals.isEmpty ? null : journals.first,
    todayJournal: todayJournal,
    recentNotes: recentNotes.take(3).toList(),
  );
});

class DashboardData {
  const DashboardData({
    required this.bestCurrentStreak,
    required this.bestLongestStreak,
    required this.todayDone,
    required this.todayTotal,
    required this.journalCount,
    required this.noteCount,
    required this.weeklyProgress,
    required this.monthlyProgress,
    required this.weekBars,
    required this.journalDayKeys,
    required this.habitDayKeys,
    required this.todayHabits,
    required this.latestJournal,
    required this.todayJournal,
    required this.recentNotes,
  });

  final int bestCurrentStreak;
  final int bestLongestStreak;
  final int todayDone;
  final int todayTotal;
  final int journalCount;
  final int noteCount;
  final double weeklyProgress;
  final double monthlyProgress;

  /// 7 values, oldest → today.
  final List<double> weekBars;
  final Set<String> journalDayKeys;
  final Set<String> habitDayKeys;
  final List<Habit> todayHabits;
  final JournalEntry? latestJournal;

  /// The journal entry written today, if any.
  final JournalEntry? todayJournal;
  final List<Note> recentNotes;
}
