import '../../core/utils/date_utils.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/mood.dart';
import 'analytics_service.dart';
import 'habit_stats.dart';

/// A pure, week-scoped snapshot for the "This Week" review screen.
///
/// The window is the trailing 7 days including today — the same convention
/// the analytics and dashboard screens use — so numbers stay comparable.
class WeekReview {
  const WeekReview({
    required this.start,
    required this.end,
    required this.weekCompletion,
    required this.lastWeekCompletion,
    required this.bestDay,
    required this.bestDayCount,
    required this.doneByDay,
    required this.journalCount,
    required this.moodStats,
    required this.topMood,
    required this.currentStreak,
    required this.streakWeekAgo,
    required this.habitStats,
  });

  final DateTime start;
  final DateTime end;

  /// Average habit completion over the window (0..1).
  final double weekCompletion;

  /// Same metric for the 7 days before the window (for trend comparison).
  final double lastWeekCompletion;

  /// The window day with the most habits done; null if none were.
  final DateTime? bestDay;
  final int bestDayCount;

  /// Habits done per window day, index 0 == [start].
  final List<int> doneByDay;

  final int journalCount;
  final List<MoodStat> moodStats;
  final Mood? topMood;

  /// Best current streak across habits, now and as of the day before the
  /// window started.
  final int currentStreak;
  final int streakWeekAgo;

  /// Per-habit completion for the window, strongest first.
  final List<HabitCompletionStat> habitStats;

  int get totalHabits => habitStats.length;
  int get streakDelta => currentStreak - streakWeekAgo;

  /// Habits that hit 100% of their target every day of the window.
  int get onTrackHabits => habitStats.where((s) => s.rate >= 1.0).length;

  /// A short, rule-based prose summary of the week.
  String get summary {
    if (journalCount == 0 && bestDayCount == 0 && currentStreak == 0) {
      return 'No activity recorded this week yet. Add a journal entry or '
          'check off a habit to start your review.';
    }
    final parts = <String>[];
    final pct = (weekCompletion * 100).round();
    final lastPct = (lastWeekCompletion * 100).round();
    if (pct > 0) {
      if (lastPct > 0 && pct != lastPct) {
        parts.add(
          'You completed $pct% of your habits this week'
          ' (${pct > lastPct ? 'up' : 'down'} from $lastPct% last week).',
        );
      } else {
        parts.add('You completed $pct% of your habits this week.');
      }
    }
    final day = bestDay;
    if (day != null) {
      parts.add(
        'Your best day was ${AppDate.weekdayName(day)} with '
        '$bestDayCount habit${bestDayCount == 1 ? '' : 's'} done.',
      );
    }
    final mood = topMood;
    if (mood != null) {
      parts.add(
        '${mood.emoji} ${mood.label} was your most frequent mood this week.',
      );
    }
    if (journalCount > 0) {
      parts.add(
        'You wrote $journalCount journal entr${journalCount == 1 ? 'y' : 'ies'}.',
      );
    }
    if (currentStreak > 0) {
      final delta = streakDelta;
      if (delta > 0) {
        parts.add(
          'Your best streak is $currentStreak days — up $delta from last week.',
        );
      } else if (delta < 0) {
        parts.add(
          'Your best streak is $currentStreak days'
          ' (down ${-delta} from last week).',
        );
      } else {
        parts.add('Your best streak is $currentStreak days.');
      }
    }
    return parts.join(' ');
  }
}

/// Pure aggregation of journals / habits / counts into a weekly review.
/// No Flutter or database imports so it can be unit-tested and reused.
class WeekReviewService {
  WeekReviewService._();

  static WeekReview build({
    required List<JournalEntry> journals,
    required List<Habit> habits,
    required Map<int, Map<String, int>> counts,
  }) {
    final end = AppDate.today();
    final start = AppDate.addDays(end, -6);
    final lastWeekEnd = AppDate.addDays(start, -1);
    final lastWeekStart = AppDate.addDays(lastWeekEnd, -6);

    double completionFor(List<Habit> hs, DateTime from, DateTime to) {
      if (hs.isEmpty) return 0;
      var sum = 0.0;
      for (final h in hs) {
        sum += HabitStats.completion(h, counts[h.id] ?? const {}, from, to);
      }
      return sum / hs.length;
    }

    // Done habits per day + the week's best day.
    final weekKeys = [
      for (var i = 0; i < 7; i++) AppDate.dayKey(AppDate.addDays(start, i)),
    ];
    final doneByDay = List<int>.filled(7, 0);
    DateTime? bestDay;
    var bestDayCount = 0;
    for (var i = 0; i < 7; i++) {
      var done = 0;
      for (final h in habits) {
        if (HabitStats.isDoneOnKey(h, counts[h.id] ?? const {}, weekKeys[i])) {
          done++;
        }
      }
      doneByDay[i] = done;
      if (done > bestDayCount) {
        bestDayCount = done;
        bestDay = AppDate.addDays(start, i);
      }
    }
    if (bestDayCount == 0) bestDay = null;

    // Journals inside the window + the mood trend.
    final moodCounts = <Mood, int>{};
    var journalCount = 0;
    for (final j in journals) {
      final d = AppDate.startOfDay(j.entryDate);
      if (d.isBefore(start) || d.isAfter(end)) continue;
      journalCount++;
      moodCounts[j.mood] = (moodCounts[j.mood] ?? 0) + 1;
    }
    final moodStats = [
      for (final m in Mood.values)
        if ((moodCounts[m] ?? 0) > 0) MoodStat(mood: m, count: moodCounts[m]!),
    ]..sort((a, b) => b.count.compareTo(a.count));
    final topMood = moodStats.isEmpty ? null : moodStats.first.mood;

    // Streaks now vs. the day before the window opened.
    var currentStreak = 0;
    var streakWeekAgo = 0;
    final weekAgoAnchor = AppDate.addDays(start, -1);
    for (final h in habits) {
      final c = counts[h.id] ?? const <String, int>{};
      final now = HabitStats.currentStreak(h, c);
      if (now > currentStreak) currentStreak = now;
      final then = HabitStats.currentStreak(h, c, today: weekAgoAnchor);
      if (then > streakWeekAgo) streakWeekAgo = then;
    }

    // Per-habit completion for the window, strongest first.
    final habitStats = [
      for (final h in habits)
        HabitCompletionStat(
          habit: h,
          doneDays: HabitStats.daysDone(h, counts[h.id] ?? const {}, start, end),
          totalDays: _totalDays(h, start, end),
        ),
    ]..sort((a, b) => b.rate.compareTo(a.rate));

    return WeekReview(
      start: start,
      end: end,
      weekCompletion: completionFor(habits, start, end),
      lastWeekCompletion: completionFor(habits, lastWeekStart, lastWeekEnd),
      bestDay: bestDay,
      bestDayCount: bestDayCount,
      doneByDay: doneByDay,
      journalCount: journalCount,
      moodStats: moodStats,
      topMood: topMood,
      currentStreak: currentStreak,
      streakWeekAgo: streakWeekAgo,
      habitStats: habitStats,
    );
  }

  /// Calendar days from the habit's creation (clamped into the window) to the
  /// window end — the same rule as `AnalyticsData.completionForWindow`.
  static int _totalDays(Habit habit, DateTime start, DateTime end) {
    final first = AppDate.startOfDay(
      DateTime.fromMillisecondsSinceEpoch(habit.createdAt),
    );
    final firstInRange = first.isAfter(start) ? first : start;
    return firstInRange.isAfter(end)
        ? 0
        : AppDate.daysBetween(firstInRange, end) + 1;
  }
}
