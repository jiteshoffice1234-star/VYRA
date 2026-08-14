import '../../core/utils/date_utils.dart';
import '../models/habit.dart';

/// Pure habit statistics: streaks, completion and "done" logic.
///
/// Counts are keyed by `yyyy-MM-dd` day key. A good habit is "done" on a day
/// when its count reaches [Habit.targetPerDay]; a bad habit is "done" when its
/// count is zero (the behavior was avoided).
class HabitStats {
  HabitStats._();

  static bool isDoneOn(Habit habit, Map<String, int> counts, DateTime day) =>
      isDoneOnKey(habit, counts, AppDate.dayKey(day));

  /// Key-based variant of [isDoneOn] for hot loops that already hold a day
  /// key, avoiding a `DateFormat` round-trip per call.
  static bool isDoneOnKey(Habit habit, Map<String, int> counts, String dayKey) {
    final count = counts[dayKey] ?? 0;
    return habit.type == HabitType.good
        ? count >= habit.targetPerDay
        : count == 0;
  }

  /// Consecutive done days ending today (or yesterday if today is not done yet).
  ///
  /// Runs over the logged day keys only — a sparse history with no logs is
  /// answered in O(logs) instead of O(elapsed days).
  static int currentStreak(
    Habit habit,
    Map<String, int> counts, {
    DateTime? today,
  }) {
    final firstDay = _start(habit);
    var day = AppDate.startOfDay(today ?? DateTime.now());
    if (isDoneOn(habit, counts, day)) {
      return _streakFrom(habit, counts, day, firstDay);
    }
    final yesterday = AppDate.addDays(day, -1);
    if (yesterday.isBefore(firstDay)) return 0;
    return _streakFrom(habit, counts, yesterday, firstDay);
  }

  /// Done-run length ending at [end] (inclusive), never before [firstDay].
  static int _streakFrom(
    Habit habit,
    Map<String, int> counts,
    DateTime end,
    DateTime firstDay,
  ) {
    // Bad habits: done on every day without a positive log, so the streak is
    // the gap since the most recent blocking log (or since creation).
    if (habit.type == HabitType.bad) {
      final endKey = AppDate.dayKey(end);
      final firstKey = AppDate.dayKey(firstDay);
      String? latestBlock;
      for (final entry in counts.entries) {
        final key = entry.key;
        if (entry.value > 0 &&
            key.compareTo(firstKey) >= 0 &&
            key.compareTo(endKey) <= 0) {
          if (latestBlock == null || key.compareTo(latestBlock) > 0) {
            latestBlock = key;
          }
        }
      }
      if (latestBlock == null) {
        return _daysBetween(firstDay, end) + 1;
      }
      return _daysBetween(AppDate.parseDayKey(latestBlock), end);
    }

    // Good habits: walk consecutive done days backwards.
    var streak = 0;
    var day = end;
    while (!day.isBefore(firstDay) && isDoneOn(habit, counts, day)) {
      streak++;
      day = AppDate.addDays(day, -1);
    }
    return streak;
  }

  /// Longest run of consecutive done days since the habit was created.
  ///
  /// Scans only the logged day keys (sorted once) rather than every elapsed
  /// day, so years of history cost O(logs · log logs) at most.
  static int longestStreak(
    Habit habit,
    Map<String, int> counts, {
    DateTime? today,
  }) {
    final end = AppDate.startOfDay(today ?? DateTime.now());
    final firstDay = _start(habit);
    if (end.isBefore(firstDay)) return 0;

    if (habit.type == HabitType.bad) {
      // Done every day except ones with a positive log; the longest run is
      // the largest gap between blocking days (bounded by creation / today).
      final blocked = counts.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toList()
        ..sort();
      var best = 0;
      var prev = AppDate.addDays(firstDay, -1);
      for (final key in blocked) {
        final b = AppDate.parseDayKey(key);
        if (b.isBefore(firstDay) || b.isAfter(end)) continue;
        final gap = _daysBetween(prev, b) - 1;
        if (gap > best) best = gap;
        prev = b;
      }
      final tail = _daysBetween(prev, end);
      return tail > best ? tail : best;
    }

    // Good habits: longest run of consecutive done day keys.
    final startKey = AppDate.dayKey(firstDay);
    final endKey = AppDate.dayKey(end);
    final keys = counts.entries
        .where(
          (e) =>
              e.value >= habit.targetPerDay &&
              e.key.compareTo(startKey) >= 0 &&
              e.key.compareTo(endKey) <= 0,
        )
        .map((e) => e.key)
        .toList()
      ..sort();

    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final key in keys) {
      final day = AppDate.parseDayKey(key);
      run = (prev != null && _daysBetween(prev, day) == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = day;
    }
    return best;
  }

  /// The count to write when [day] is toggled: good habits jump to the
  /// target (or 0 to undo), bad habits flip between 0 (avoided) and 1
  /// (slipped). Shared by today's check button and past-day calendar logging.
  static int toggleCount(
    Habit habit,
    Map<String, int> counts,
    DateTime day,
  ) {
    final done = isDoneOn(habit, counts, day);
    return habit.type == HabitType.good
        ? (done ? 0 : habit.targetPerDay)
        : (done ? 1 : 0);
  }

  /// Days done (inclusive range, clamped to after creation) / days elapsed.
  static double completion(
    Habit habit,
    Map<String, int> counts,
    DateTime start,
    DateTime end,
  ) {
    final firstDay = _start(habit);
    final from = AppDate.startOfDay(start);
    final rangeStart = from.isBefore(firstDay) ? firstDay : from;
    final last = AppDate.startOfDay(end);
    if (rangeStart.isAfter(last)) return 0;
    final total = AppDate.daysBetween(rangeStart, last) + 1;
    final done = daysDone(habit, counts, rangeStart, last);
    return total == 0 ? 0 : done / total;
  }

  /// Completion over the last 7 days including today.
  static double weekCompletion(Habit habit, Map<String, int> counts) {
    final end = AppDate.today();
    return completion(habit, counts, AppDate.addDays(end, -6), end);
  }

  /// Completion for the current month up to today.
  static double monthCompletion(Habit habit, Map<String, int> counts) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return completion(habit, counts, start, now);
  }

  /// Number of done days in the given range, counted from logged keys.
  static int daysDone(
    Habit habit,
    Map<String, int> counts,
    DateTime start,
    DateTime end,
  ) {
    final firstDay = _start(habit);
    final from = AppDate.startOfDay(start);
    final rangeStart = from.isBefore(firstDay) ? firstDay : from;
    final last = AppDate.startOfDay(end);
    if (rangeStart.isAfter(last)) return 0;

    final fromKey = AppDate.dayKey(rangeStart);
    final lastKey = AppDate.dayKey(last);

    if (habit.type == HabitType.bad) {
      // Done on every day in range unless a log records a positive count.
      var blocked = 0;
      for (final entry in counts.entries) {
        if (entry.value > 0 &&
            entry.key.compareTo(fromKey) >= 0 &&
            entry.key.compareTo(lastKey) <= 0) {
          blocked++;
        }
      }
      return _daysBetween(rangeStart, last) + 1 - blocked;
    }

    var done = 0;
    for (final entry in counts.entries) {
      if (entry.value >= habit.targetPerDay &&
          entry.key.compareTo(fromKey) >= 0 &&
          entry.key.compareTo(lastKey) <= 0) {
        done++;
      }
    }
    return done;
  }

  static DateTime _start(Habit habit) =>
      AppDate.startOfDay(DateTime.fromMillisecondsSinceEpoch(habit.createdAt));

  /// Calendar-day difference between two local midnights (DST-safe).
  static int _daysBetween(DateTime a, DateTime b) => AppDate.daysBetween(a, b);
}
