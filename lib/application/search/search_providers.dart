import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/search_result.dart';
import '../../domain/services/universal_search.dart';
import '../categories/category_providers.dart';
import '../habits/habit_providers.dart';
import '../journal/journal_providers.dart';
import '../notes/note_providers.dart';
import '../providers/app_providers.dart';
import '../tags/tag_providers.dart';

/// Instant (debounced) search input. Typing updates the value 150ms after the
/// user pauses so large datasets aren't rescanned on every keystroke.
final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  void update(String value) {
    if (value == state) return;
    _debounce?.cancel();
    if (value.isEmpty) {
      state = '';
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 150), () => state = value);
  }

  void clear() {
    _debounce?.cancel();
    state = '';
  }
}

/// Active type filters. An empty set would hide everything; the screen always
/// offers "All types" to reset it.
final searchTypeFilterProvider =
    StateProvider<Set<SearchItemType>>((ref) => SearchItemType.values.toSet());

/// false = relevance order, true = newest first.
final searchSortNewestProvider = StateProvider<bool>((ref) => false);

/// The pluggable engine. Swap this single provider to move from keyword
/// matching to AI / semantic search without touching any UI.
final searchEngineProvider =
    Provider<UniversalSearchEngine>((ref) => const KeywordSearchEngine());

/// Debounced, filtered and sorted results across journals, notes, habits,
/// categories and tags. Recomputes automatically whenever any source list or
/// the query changes.
final searchResultsProvider =
    FutureProvider<List<UniversalSearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  final types = ref.watch(searchTypeFilterProvider);
  final sortNewest = ref.watch(searchSortNewestProvider);
  final engine = ref.watch(searchEngineProvider);

  final journals = await ref.watch(journalListProvider.future);
  final notes = await ref.watch(notesProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final tags = await ref.watch(tagProvider.future);

  return engine.search(SearchRequest(
    query: query,
    types: types,
    journals: journals,
    notes: notes,
    habits: habits,
    categories: categories,
    tags: tags,
    sortNewest: sortNewest,
  ));
});

/// Recent searches, persisted with shared_preferences.
final searchHistoryProvider =
    AsyncNotifierProvider<SearchHistoryNotifier, List<String>>(
        SearchHistoryNotifier.new);

class SearchHistoryNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final repo = await ref.watch(searchHistoryRepositoryProvider.future);
    return repo.load();
  }

  /// Adds a query to the front of the history (deduplicated).
  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final repo = await ref.read(searchHistoryRepositoryProvider.future);
    final current = [...(state.valueOrNull ?? const <String>[])];
    current.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    current.insert(0, q);
    await repo.save(current);
    state = AsyncData(current);
  }

  Future<void> remove(String query) async {
    final repo = await ref.read(searchHistoryRepositoryProvider.future);
    final current = [...(state.valueOrNull ?? const <String>[])];
    current.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    await repo.save(current);
    state = AsyncData(current);
  }

  Future<void> clear() async {
    final repo = await ref.read(searchHistoryRepositoryProvider.future);
    await repo.save(const []);
    state = const AsyncData(<String>[]);
  }
}
