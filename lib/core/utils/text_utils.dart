/// Small text helpers shared across the app.
class TextUtil {
  TextUtil._();

  static int wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  static int charCount(String text) => text.length;

  static String excerpt(String text, {int maxChars = 120}) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars).trimRight()}…';
  }

  static String plural(int n, String word) =>
      n == 1 ? '$n $word' : '$n ${word}s';
}
