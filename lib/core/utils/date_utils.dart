import 'package:intl/intl.dart';

/// Date helpers. Day keys are `yyyy-MM-dd` strings stored in SQLite.
class AppDate {
  AppDate._();

  static final DateFormat _fullFormat = DateFormat('EEEE, MMMM d');
  static final DateFormat _mediumFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _shortFormat = DateFormat('MMM d');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _weekdayLetterFormat = DateFormat('E');
  static final DateFormat _weekdayFullFormat = DateFormat('EEEE');
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  /// `yyyy-MM-dd` key for a day.
  ///
  /// Hand-rolled instead of `DateFormat` because it is called in hot loops
  /// (dashboard aggregation, timeline building) thousands of times per
  /// recompute; manual formatting is several times faster.
  static String dayKey(DateTime d) {
    final year = d.year;
    final month = d.month;
    final day = d.day;
    // Fast path: months/days >= 10 need no padding.
    if (month >= 10 && day >= 10) {
      return '$year-$month-$day';
    }
    final mm = month < 10 ? '0$month' : '$month';
    final dd = day < 10 ? '0$day' : '$day';
    return '$year-$mm-$dd';
  }

  static DateTime parseDayKey(String key) => DateTime.parse(key);

  /// Today at midnight.
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whole calendar days from [a] to [b] (may be negative).
  ///
  /// Computed in UTC so DST transitions (23/25-hour days) can't skew the
  /// result — day-key-based date arithmetic must count calendar days, not
  /// elapsed hours.
  static int daysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isToday(DateTime d) => isSameDay(d, DateTime.now());

  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  static String monthYear(DateTime d) => _monthYearFormat.format(d);

  static String formatFull(DateTime d) => _fullFormat.format(d);

  static String formatMedium(DateTime d) => _mediumFormat.format(d);

  static String formatShort(DateTime d) => _shortFormat.format(d);

  static String formatTime(DateTime d) => _timeFormat.format(d);

  /// Two-letter weekday label, e.g. "Mo", "We". Falls back to the full
  /// label when the locale yields a shorter string (avoids a RangeError).
  static String weekdayLetter(DateTime d) {
    final label = _weekdayLetterFormat.format(d);
    return label.length >= 2 ? label.substring(0, 2) : label;
  }

  /// Full weekday name, e.g. "Tuesday".
  static String weekdayName(DateTime d) => _weekdayFullFormat.format(d);

  /// Time-of-day greeting.
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
