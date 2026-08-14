import 'package:flutter/material.dart';

/// App-wide constants: names, palettes, icons and quotes.
class AppConstants {
  AppConstants._();

  static const String appName = 'VYRA';
  static const String appVersion = '1.0.0';
  static const String tagline = 'Plan. Reflect. Grow.';

  /// Uniform page padding used across screens.
  static const double pagePadding = 20;

  /// Radius used by premium cards.
  static const double cardRadius = 22;

  /// Accent seed colors (theme selection in Settings).
  static const List<Color> seedColors = [
    Color(0xFF6C5CE7), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFF43F5E), // rose
    Color(0xFF8B5CF6), // violet
  ];

  /// Habit label colors.
  static const List<Color> habitColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  /// Note card colors.
  static const List<Color> noteColors = [
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF0EA5E9),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF43F5E),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
  ];

  /// Icons available for habits (index stored in the database).
  static const List<IconData> habitIcons = [
    Icons.fitness_center,
    Icons.directions_run,
    Icons.directions_walk,
    Icons.directions_bike,
    Icons.self_improvement,
    Icons.spa,
    Icons.bedtime,
    Icons.water_drop,
    Icons.local_drink,
    Icons.restaurant,
    Icons.no_food,
    Icons.smoke_free,
    Icons.smartphone,
    Icons.sports_esports,
    Icons.menu_book,
    Icons.school,
    Icons.work,
    Icons.code,
    Icons.savings,
    Icons.shopping_cart,
    Icons.coffee,
    Icons.music_note,
    Icons.cleaning_services,
    Icons.pets,
  ];
}

/// A hardcoded motivational quote.
class Quote {
  const Quote(this.text, this.author);

  final String text;
  final String author;
}

/// Rotating quote of the day.
const List<Quote> kQuotes = [
  Quote('The secret of getting ahead is getting started.', 'Mark Twain'),
  Quote('Habits are the compound interest of self-improvement.', 'James Clear'),
  Quote('A journey of a thousand miles begins with a single step.', 'Lao Tzu'),
  Quote('You do not rise to the level of your goals. You fall to the level of your systems.', 'James Clear'),
  Quote('The future depends on what you do today.', 'Mahatma Gandhi'),
  Quote('Small deeds done are better than great deeds planned.', 'Peter Marshall'),
  Quote('It always seems impossible until it\u2019s done.', 'Nelson Mandela'),
  Quote('Consistency is what transforms average into excellence.', 'Anonymous'),
  Quote('Discipline is choosing between what you want now and what you want most.', 'Abraham Lincoln'),
  Quote('The best time to plant a tree was 20 years ago. The second best time is now.', 'Chinese proverb'),
  Quote('Don\u2019t watch the clock; do what it does. Keep going.', 'Sam Levenson'),
  Quote('Success is the sum of small efforts, repeated day in and day out.', 'Robert Collier'),
  Quote('Reflect upon your present blessings.', 'Charles Dickens'),
  Quote('Progress, not perfection.', 'Anonymous'),
  Quote('Every day is a new beginning.', 'Anonymous'),
  Quote('Write what should not be forgotten.', 'Isabel Allende'),
];

/// Returns the quote for today, stable within a day.
Quote quoteOfTheDay() {
  final now = DateTime.now();
  // Compute in UTC so DST transitions (23/25-hour days) can't shift the
  // day-of-year by one — see AppDate.daysBetween for the same rationale.
  final today = DateTime.utc(now.year, now.month, now.day);
  final startOfYear = DateTime.utc(now.year, 1, 1);
  final dayOfYear = today.difference(startOfYear).inDays + 1;
  return kQuotes[dayOfYear % kQuotes.length];
}
