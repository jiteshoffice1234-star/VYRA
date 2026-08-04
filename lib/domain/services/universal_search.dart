import '../models/category.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/note.dart';
import '../models/search_result.dart';
import '../models/tag.dart';
import '../../core/utils/text_utils.dart';

/// Everything a search engine needs to produce results.
class SearchRequest {
  const SearchRequest({
    required this.query,
    required this.types,
    required this.journals,
    required this.notes,
    required this.habits,
    required this.categories,
    required this.tags,
    this.sortNewest = false,
    this.limitPerType = 20,
  });

  final String query;
  final Set<SearchItemType> types;
  final List<JournalEntry> journals;
  final List<Note> notes;
  final List<Habit> habits;
  final List<Category> categories;
  final List<Tag> tags;
  final bool sortNewest;
  final int limitPerType;
}

/// Pluggable search contract.
///
/// [KeywordSearchEngine] powers VYRA today; a future AI / semantic engine
/// (e.g. NVIDIA NIM embeddings) can implement the same interface and be
/// swapped in via `searchEngineProvider` without touching the UI.
abstract class UniversalSearchEngine {
  Future<List<UniversalSearchResult>> search(SearchRequest request);
}

/// Fast, dependency-free keyword matcher over the in-memory lists.
///
/// Case-insensitive substring matching with a simple relevance score:
/// title/name matches outweigh body matches, and earlier matches outweigh
/// later ones. Runs synchronously over the loaded lists, which keeps even
/// large datasets responsive (and safe to run after a short input debounce).
class KeywordSearchEngine implements UniversalSearchEngine {
  const KeywordSearchEngine();

  static const int _titleWeight = 100;
  static const int _nameWeight = 60;
  static const int _contentWeight = 30;

  @override
  Future<List<UniversalSearchResult>> search(SearchRequest request) async {
    final query = request.query.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final results = <UniversalSearchResult>[];
    if (request.types.contains(SearchItemType.journal)) {
      results.addAll(_searchJournals(request, query));
    }
    if (request.types.contains(SearchItemType.note)) {
      results.addAll(_searchNotes(request, query));
    }
    if (request.types.contains(SearchItemType.habit)) {
      results.addAll(_searchHabits(request, query));
    }
    if (request.types.contains(SearchItemType.category)) {
      results.addAll(_searchCategories(request, query));
    }
    if (request.types.contains(SearchItemType.tag)) {
      results.addAll(_searchTags(request, query));
    }

    if (request.sortNewest) {
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      results.sort((a, b) => b.score.compareTo(a.score));
    }
    return results;
  }

  List<UniversalSearchResult> _searchJournals(
    SearchRequest request,
    String query,
  ) {
    final out = <UniversalSearchResult>[];
    for (final e in request.journals) {
      final id = e.id;
      if (id == null) continue;
      final score = _matchScore(e.title, query, _titleWeight) +
          _matchScore(e.content, query, _contentWeight) +
          (e.tags.any((t) => t.toLowerCase().contains(query)) ? 20 : 0);
      if (score == 0) continue;
      out.add(UniversalSearchResult(
        type: SearchItemType.journal,
        id: id,
        title: e.title,
        subtitle: TextUtil.excerpt(e.content, maxChars: 120),
        timestamp: e.updatedAt,
        score: score,
      ));
      if (out.length >= request.limitPerType) break;
    }
    return out;
  }

  List<UniversalSearchResult> _searchNotes(SearchRequest request, String query) {
    final out = <UniversalSearchResult>[];
    for (final n in request.notes) {
      final id = n.id;
      if (id == null) continue;
      final score = _matchScore(n.title, query, _titleWeight) +
          _matchScore(n.content, query, _contentWeight) +
          (n.tags.any((t) => t.toLowerCase().contains(query)) ? 20 : 0);
      if (score == 0) continue;
      out.add(UniversalSearchResult(
        type: SearchItemType.note,
        id: id,
        title: n.title,
        subtitle: n.type == NoteType.text
            ? TextUtil.excerpt(n.content, maxChars: 120)
            : '${n.checkedCount}/${n.items.length} checklist items',
        timestamp: n.updatedAt,
        score: score,
      ));
      if (out.length >= request.limitPerType) break;
    }
    return out;
  }

  List<UniversalSearchResult> _searchHabits(
    SearchRequest request,
    String query,
  ) {
    final out = <UniversalSearchResult>[];
    for (final h in request.habits) {
      final id = h.id;
      if (id == null) continue;
      final score = _matchScore(h.name, query, _titleWeight) +
          _matchScore(h.description, query, _nameWeight);
      if (score == 0) continue;
      out.add(UniversalSearchResult(
        type: SearchItemType.habit,
        id: id,
        title: h.name,
        subtitle: h.description,
        timestamp: h.createdAt,
        score: score,
      ));
      if (out.length >= request.limitPerType) break;
    }
    return out;
  }

  List<UniversalSearchResult> _searchCategories(
    SearchRequest request,
    String query,
  ) {
    final out = <UniversalSearchResult>[];
    for (final c in request.categories) {
      final id = c.id;
      if (id == null) continue;
      final score = _matchScore(c.name, query, _nameWeight);
      if (score == 0) continue;
      out.add(UniversalSearchResult(
        type: SearchItemType.category,
        id: id,
        title: c.name,
        subtitle: c.kind == CategoryKind.habit
            ? 'Habit category'
            : 'Note category',
        timestamp: 0,
        score: score,
        categoryKind: c.kind,
      ));
      if (out.length >= request.limitPerType) break;
    }
    return out;
  }

  List<UniversalSearchResult> _searchTags(SearchRequest request, String query) {
    final out = <UniversalSearchResult>[];
    for (final t in request.tags) {
      final id = t.id;
      if (id == null) continue;
      final score = _matchScore(t.name, query, _nameWeight);
      if (score == 0) continue;
      out.add(UniversalSearchResult(
        type: SearchItemType.tag,
        id: id,
        title: t.name,
        subtitle: 'Tag',
        timestamp: t.createdAt,
        score: score,
      ));
      if (out.length >= request.limitPerType) break;
    }
    return out;
  }

  /// Relevance score for one field: [weight] when the match starts at the
  /// beginning, decreasing as the match moves later in the string, 0 if none.
  static int _matchScore(String text, String query, int weight) {
    final index = text.toLowerCase().indexOf(query);
    if (index == -1) return 0;
    return (weight - index).clamp(1, weight);
  }
}
