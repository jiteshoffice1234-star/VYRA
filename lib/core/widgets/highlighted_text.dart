import 'package:flutter/material.dart';

/// A [start, end) range of characters inside a string.
class HighlightRange {
  const HighlightRange(this.start, this.end);

  final int start;
  final int end;

  bool get isEmpty => end <= start;
}

/// Every case-insensitive occurrence of [query] in [text].
List<HighlightRange> highlightRanges(String text, String query) {
  final ranges = <HighlightRange>[];
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return ranges;
  final lower = text.toLowerCase();
  var index = 0;
  while (index < lower.length) {
    index = lower.indexOf(needle, index);
    if (index == -1) break;
    ranges.add(HighlightRange(index, index + needle.length));
    index += needle.length;
  }
  return ranges;
}

/// Text that emphasises every occurrence of [query].
///
/// Falls back to a plain [Text] when there is nothing to highlight, so list
/// items stay cheap to rebuild.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final ranges = highlightRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: base,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final highlighted = highlightStyle ??
        base.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(text: text.substring(range.start, range.end), style: highlighted),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
