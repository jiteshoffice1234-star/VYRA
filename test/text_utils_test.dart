import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/utils/date_utils.dart';
import 'package:vyra/core/utils/text_utils.dart';

void main() {
  group('TextUtil', () {
    test('wordCount counts words', () {
      expect(TextUtil.wordCount(''), 0);
      expect(TextUtil.wordCount('   '), 0);
      expect(TextUtil.wordCount('hello world'), 2);
      expect(TextUtil.wordCount('  hello   world  '), 2);
    });

    test('charCount counts characters', () {
      expect(TextUtil.charCount('abc'), 3);
      expect(TextUtil.charCount(''), 0);
    });

    test('excerpt truncates and ellipsizes', () {
      final long = 'a' * 200;
      expect(TextUtil.excerpt(long, maxChars: 50).length, 51);
      expect(TextUtil.excerpt('short text', maxChars: 50), 'short text');
      expect(TextUtil.excerpt(long, maxChars: 50), endsWith('…'));
    });

    test('plural handles singular and plural', () {
      expect(TextUtil.plural(1, 'entry'), '1 entry');
      expect(TextUtil.plural(3, 'entry'), '3 entries');
    });
  });

  group('AppDate', () {
    test('dayKey round-trips', () {
      final day = DateTime(2026, 8, 4);
      expect(AppDate.dayKey(day), '2026-08-04');
      expect(AppDate.parseDayKey('2026-08-04'), DateTime(2026, 8, 4));
    });

    test('isSameDay compares dates', () {
      expect(
        AppDate.isSameDay(DateTime(2026, 8, 4, 23), DateTime(2026, 8, 4, 1)),
        isTrue,
      );
      expect(
        AppDate.isSameDay(DateTime(2026, 8, 4), DateTime(2026, 8, 5)),
        isFalse,
      );
    });

    test('greeting varies by hour', () {
      expect(AppDate.greeting(DateTime(2026, 8, 4, 9)), 'Good morning');
      expect(AppDate.greeting(DateTime(2026, 8, 4, 14)), 'Good afternoon');
      expect(AppDate.greeting(DateTime(2026, 8, 4, 20)), 'Good evening');
    });

    test('daysInMonth is correct', () {
      expect(AppDate.daysInMonth(DateTime(2026, 2)), 28);
      expect(AppDate.daysInMonth(DateTime(2024, 2)), 29);
      expect(AppDate.daysInMonth(DateTime(2026, 8)), 31);
    });

    test('addDays handles month boundaries', () {
      expect(AppDate.addDays(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 1));
      expect(AppDate.addDays(DateTime(2026, 8, 1), -1), DateTime(2026, 7, 31));
    });
  });
}
