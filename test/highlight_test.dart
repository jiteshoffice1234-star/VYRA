import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/widgets/highlighted_text.dart';

void main() {
  group('highlightRanges', () {
    test('empty query yields no ranges', () {
      expect(highlightRanges('hello world', ''), isEmpty);
      expect(highlightRanges('hello world', '   '), isEmpty);
    });

    test('finds a single case-insensitive match', () {
      final ranges = highlightRanges('Run in the park', 'run');
      expect(ranges, hasLength(1));
      expect(ranges.single.start, 0);
      expect(ranges.single.end, 3);
    });

    test('finds multiple occurrences', () {
      final ranges = highlightRanges('cat and catalog cat', 'cat');
      expect(ranges, hasLength(3));
      expect(ranges[0].start, 0);
      expect(ranges[1].start, 9);
      expect(ranges[2].start, 17);
    });

    test('no match yields no ranges', () {
      expect(highlightRanges('hello world', 'xyz'), isEmpty);
    });

    test('adjacent non-overlapping matches are found', () {
      final ranges = highlightRanges('aa aa', 'aa');
      expect(ranges, hasLength(2));
      expect(ranges[0].start, 0);
      expect(ranges[1].start, 3);
    });
  });
}
