import '../../core/utils/date_utils.dart';
import '../models/category.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/mood.dart';
import '../models/note.dart';
import 'habit_stats.dart';

/// A habit's completion rate over one window.
class HabitCompletionStat {
  const HabitCompletionStat({
    required this.habit,
    required this.doneDays,
    required this.totalDays,
  });

  final Habit habit;
  final int doneDays;
  final int totalDays;

  double get rate => totalDays == 0 ? 0 : doneDays / totalDays;
}

/// Mood → journal entry count.
class MoodStat {
  const MoodStat({required this.mood, required this.count});

  final Mood mood;
  final int count;
}

/// Aggregated journal activity bucketed by month (yyyy-MM).
class JournalFrequency {
  const JournalFrequency({
    required this.month,
    required this.count,
  });

  final DateTime month; // first day of the month
  final int count;
}

/// Category aggregates for one kind (habit or note).
class CategoryStat {
  const CategoryStat({
    required this.name,
    required this.color,
    required this.count,
    this.rate,
  });

  final String name;
  final int? color; // ARGB; null when the item has no category
  final int count;
  final double? rate; // completion rate, habits only
}

/// One recent activity row: journal write, note save or habit completion.
class ActivityEntry {
  const ActivityEntry({
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final int timestamp;
  final String icon; // emoji glyph
  final int? color; // ARGB accent; null → theme default
  final String title;
  final String subtitle;
}

/// Everything the analytics screen needs, computed in one pass.
class AnalyticsData {
  const AnalyticsData({
    required this.habits,
    required this.moodStats,
    required this.journalFrequency,
    required this.totalJournals,
    required this.totalNotes,
    required this.totalHabits,
    required this.activeHabits,
    required this.bestStreak,
    required this.currentStreak,
    required this.weekCompletion,
    required this.monthCompletion,
    required this.bestDay,
    required this.bestDayCount,
    required this.bestMonth,
    required this.bestMonthRate,
    required this.habitCategoryStats,
    required this.noteCategoryStats,
    required this.recentActivity,
    this.counts = const {},
  });

  /// Habits used by the completion charts (includes archived ones).
  final List<Habit> habits;
  final List<MoodStat> moodStats;
  final List<JournalFrequency> journalFrequency;
  final int totalJournals;
  final int totalNotes;
  final int totalHabits;
  final int activeHabits;
  final int bestStreak;
  final int currentStreak;
  final double weekCompletion;
  final double monthCompletion;
  final DateTime? bestDay;
  final int bestDayCount;
  final DateTime? bestMonth;
  final double bestMonthRate;
  final List<CategoryStat> habitCategoryStats;
  final List<CategoryStat> noteCategoryStats;
  final List<ActivityEntry> recentActivity;

  /// habit id → (dayKey → count), carried through so UI callers can compute
  /// per-window completion stats with the real data.
  final Map<int, Map<String, int>> counts;

  /// Completion stats for the last [days] days, per habit (used by charts).
  List<HabitCompletionStat> completionForWindow(
    List<Habit> habits,
    Map<int, Map<String, int>> counts,
    int days,
  ) {
    final end = AppDate.today();
    final start = AppDate.addDays(end, -(days - 1));
    final out = <HabitCompletionStat>[];
    for (final habit in habits) {
      final c = counts[habit.id] ?? const <String, int>{};
      final done = HabitStats.daysDone(habit, c, start, end);
      final first = AppDate.startOfDay(
        DateTime.fromMillisecondsSinceEpoch(habit.createdAt),
      );
      final firstInRange = first.isAfter(start) ? first : start;
      final total = firstInRange.isAfter(end)
          ? 0
          : AppDate.daysBetween(firstInRange, end) + 1;
      out.add(
        HabitCompletionStat(habit: habit, doneDays: done, totalDays: total),
      );
    }
    out.sort((a, b) => b.rate.compareTo(a.rate));
    return out;
  }
}

/// Pure analytics. No Flutter / database imports so it can be unit tested and
/// reused (widgets, export, future AI summaries).
class AnalyticsService {
  AnalyticsService._();

  static AnalyticsData compute({
    required List<JournalEntry> journals,
    required List<Note> notes,
    required List<Habit> habits,
    required List<Category> categories,
    required Map<int, Map<String, int>> counts,
  }) {
    final habitsAll = habits.where((h) => !h.archived).toList();
    // ---- moods ----
    final moodCounts = <Mood, int>{};
    for (final e in journals) {
      moodCounts[e.mood] = (moodCounts[e.mood] ?? 0) + 1;
    }
    final moodStats = [
      for (final mood in Mood.values)
        if ((moodCounts[mood] ?? 0) > 0)
          MoodStat(mood: mood, count: moodCounts[mood]!),
    ]..sort((a, b) => b.count.compareTo(a.count));

    // ---- journal frequency (by month) ----
    final freqMap = <String, int>{};
    for (final e in journals) {
      final key = '${e.entryDate.year}-${e.entryDate.month}';
      freqMap[key] = (freqMap[key] ?? 0) + 1;
    }
    final journalFrequency = <JournalFrequency>[
      for (final e in freqMap.entries)
        JournalFrequency(
          // Parse the two parts numerically — `DateTime.parse` requires
          // zero-padded months (e.g. '2026-8-01') which would throw.
          month: DateTime(
            int.parse(e.key.split('-')[0]),
            int.parse(e.key.split('-')[1]),
            1,
          ),
          count: e.value,
        ),
    ]..sort((a, b) => a.month.compareTo(b.month));

    // ---- streaks & best day / month ----
    var bestStreak = 0;
    var currentStreak = 0;
    final doneByDay = <String, int>{};
    for (final habit in habits) {
      final c = counts[habit.id] ?? const <String, int>{};
      final longest = HabitStats.longestStreak(habit, c);
      if (longest > bestStreak) bestStreak = longest;
      final cur = HabitStats.currentStreak(habit, c);
      if (cur > currentStreak) currentStreak = cur;
      for (final dayKey in c.keys) {
        final day = AppDate.parseDayKey(dayKey);
        if (HabitStats.isDoneOn(habit, c, day)) {
          doneByDay[dayKey] = (doneByDay[dayKey] ?? 0) + 1;
        }
      }
    }

    DateTime? bestDay;
    var bestDayCount = 0;
    for (final e in doneByDay.entries) {
      if (e.value > bestDayCount) {
        bestDayCount = e.value;
        bestDay = AppDate.parseDayKey(e.key);
      }
    }

    // Best month = month with the highest average habit completion.
    DateTime? bestMonth;
    var bestMonthRate = -1.0;
    if (habits.isNotEmpty) {
      final monthTotal = <String, int>{};
      final monthDone = <String, int>{};
      final end = AppDate.today();
      for (final habit in habits) {
        final c = counts[habit.id] ?? const <String, int>{};
        final start = AppDate.startOfDay(
          DateTime.fromMillisecondsSinceEpoch(habit.createdAt),
        );
        // Iterate whole months instead of every single day, and count done
        // days from the logged keys — O(months + logs) rather than
        // O(elapsed days) per habit.
        var month = DateTime(start.year, start.month, 1);
        while (!month.isAfter(end)) {
          final key = '${month.year}-${month.month}';
          final monthEnd = DateTime(month.year, month.month + 1, 0);
          final last = monthEnd.isAfter(end) ? end : monthEnd;
          final first = month.isBefore(start) ? start : month;
          monthTotal[key] = (monthTotal[key] ?? 0) +
              (AppDate.daysBetween(first, last) + 1);
          monthDone[key] =
              (monthDone[key] ?? 0) + HabitStats.daysDone(habit, c, first, last);
          month = DateTime(month.year, month.month + 1, 1);
        }
      }
      for (final e in monthTotal.entries) {
        final rate = (monthDone[e.key] ?? 0) / e.value;
        if (rate > bestMonthRate) {
          bestMonthRate = rate;
          final parts = e.key.split('-');
          bestMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        }
      }
    }
    if (bestMonthRate < 0) bestMonthRate = 0;

    // ---- category stats ----
    final habitByCat = <int?, List<Habit>>{};
    for (final h in habits) {
      habitByCat.putIfAbsent(h.categoryId, () => []).add(h);
    }
    final catById = {for (final c in categories) c.id: c};
    final habitCategoryStats = <CategoryStat>[];
    for (final e in habitByCat.entries) {
      final cat = e.key == null ? null : catById[e.key];
      var done = 0;
      var total = 0;
      for (final habit in e.value) {
        final c = counts[habit.id] ?? const <String, int>{};
        final start = AppDate.startOfDay(
          DateTime.fromMillisecondsSinceEpoch(habit.createdAt),
        );
        final end = AppDate.today();
        final stats = HabitStats.daysDone(habit, c, start, end);
        done += stats;
        final first = start.isAfter(end) ? end : start;
        total += AppDate.daysBetween(first, end) + 1;
      }
      habitCategoryStats.add(
        CategoryStat(
          name: cat?.name ?? 'Uncategorized',
          color: cat?.color,
          count: e.value.length,
          rate: total == 0 ? null : done / total,
        ),
      );
    }
    habitCategoryStats.sort((a, b) => (b.rate ?? 0).compareTo(a.rate ?? 0));

    final noteByCat = <int?, List<Note>>{};
    for (final n in notes) {
      noteByCat.putIfAbsent(n.categoryId, () => []).add(n);
    }
    final noteCategoryStats = <CategoryStat>[
      for (final e in noteByCat.entries)
        CategoryStat(
          name: e.key == null
              ? 'Uncategorized'
              : catById[e.key]?.name ?? 'Uncategorized',
          color: e.key == null ? null : catById[e.key]?.color,
          count: e.value.length,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));

    // ---- recent activity ----
    final habitById = {for (final h in habits) h.id: h};
    final activity = <ActivityEntry>[
      for (final e in journals)
        ActivityEntry(
          timestamp: e.updatedAt,
          icon: e.mood.emoji,
          color: _moodColors[e.mood] ?? 0xFF94A3B8,
          title: 'Journaled',
          subtitle: e.title,
        ),
      for (final n in notes)
        ActivityEntry(
          timestamp: n.updatedAt,
          icon: '🗒️',
          color: 0xFFF59E0B,
          title: n.type == NoteType.checklist ? 'Updated checklist' : 'Saved note',
          subtitle: n.title,
        ),
      // Logs whose habit is missing from the loaded list are skipped (the
      // habit may have been deleted between queries) — never fall back to an
      // arbitrary habit, which would compute done-ness against the wrong
      // target/type.
      for (final e in counts.entries)
        if (habitById[e.key] case final habit?)
          for (final dayKey in e.value.keys)
            if (HabitStats.isDoneOnKey(habit, e.value, dayKey))
              ActivityEntry(
                timestamp: AppDate.parseDayKey(dayKey)
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch,
                icon: '✅',
                color: 0xFF10B981,
                title: 'Habit completed',
                subtitle: '${habit.name} · $dayKey',
              ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return AnalyticsData(
      habits: habitsAll,
      moodStats: moodStats,
      journalFrequency: journalFrequency,
      totalJournals: journals.length,
      totalNotes: notes.length,
      totalHabits: habits.length,
      activeHabits: habitsAll.length,
      bestStreak: bestStreak,
      currentStreak: currentStreak,
      weekCompletion: _completion(habits, counts, 7),
      monthCompletion: _completion(habits, counts, 30),
      bestDay: bestDay,
      bestDayCount: bestDayCount,
      bestMonth: bestMonth,
      bestMonthRate: bestMonthRate,
      habitCategoryStats: habitCategoryStats,
      noteCategoryStats: noteCategoryStats,
      recentActivity: activity.take(12).toList(),
      counts: counts,
    );
  }

  /// Average completion rate across habits over the last [days] days.
  static double _completion(
    List<Habit> habits,
    Map<int, Map<String, int>> counts,
    int days,
  ) {
    if (habits.isEmpty) return 0;
    final end = AppDate.today();
    final start = AppDate.addDays(end, -(days - 1));
    var sum = 0.0;
    for (final habit in habits) {
      final c = counts[habit.id] ?? const <String, int>{};
      sum += HabitStats.completion(habit, c, start, end);
    }
    return sum / habits.length;
  }

  static const Map<Mood, int> _moodColors = {
    Mood.happy: 0xFFF59E0B,
    Mood.excited: 0xFFEC4899,
    Mood.grateful: 0xFF10B981,
    Mood.calm: 0xFF14B8A6,
    Mood.focused: 0xFF6366F1,
    Mood.neutral: 0xFF94A3B8,
    Mood.tired: 0xFF8B5CF6,
    Mood.anxious: 0xFFF97316,
    Mood.sad: 0xFF3B82F6,
    Mood.angry: 0xFFEF4444,
  };
}
