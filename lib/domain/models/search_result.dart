import 'category.dart';

/// What kind of record a search result points at.
enum SearchItemType {
  journal,
  note,
  habit,
  category,
  tag,
}

/// A single match returned by any [UniversalSearchEngine].
///
/// [score] is engine-specific (relevance); [timestamp] lets clients sort by
/// recency; [categoryKind] is set for category results so taps can route to
/// the right module.
class UniversalSearchResult {
  const UniversalSearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.score,
    this.categoryKind,
  });

  final SearchItemType type;
  final int id;
  final String title;
  final String subtitle;
  final int timestamp;
  final int score;
  final CategoryKind? categoryKind;
}
