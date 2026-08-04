import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/list_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/models/journal_entry.dart';
import '../providers/app_providers.dart';
import '../tags/tag_providers.dart';

/// The full journal, newest first.
final journalListProvider =
    AsyncNotifierProvider<JournalNotifier, List<JournalEntry>>(JournalNotifier.new);

/// Search / filter state.
final journalSearchProvider = StateProvider<String>((ref) => '');
final journalDateProvider = StateProvider<DateTime?>((ref) => null);
final journalFavoritesOnlyProvider = StateProvider<bool>((ref) => false);
final journalSortNewestProvider = StateProvider<bool>((ref) => true);

/// Filtered, sorted journal derived from [journalListProvider].
final filteredJournalListProvider = Provider<AsyncValue<List<JournalEntry>>>((ref) {
  final query = ref.watch(journalSearchProvider).trim().toLowerCase();
  final date = ref.watch(journalDateProvider);
  final favoritesOnly = ref.watch(journalFavoritesOnlyProvider);
  final newest = ref.watch(journalSortNewestProvider);

  return ref.watch(journalListProvider).whenData((entries) {
    final filtered = entries.where((e) {
      if (query.isNotEmpty &&
          !e.title.toLowerCase().contains(query) &&
          !e.content.toLowerCase().contains(query) &&
          !e.tags.any((t) => t.toLowerCase().contains(query))) {
        return false;
      }
      if (date != null && !AppDate.isSameDay(e.entryDate, date)) return false;
      if (favoritesOnly && !e.isFavorite) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => newest
        ? b.entryDate.compareTo(a.entryDate)
        : a.entryDate.compareTo(b.entryDate));
    return filtered;
  });
});

class JournalNotifier extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() async {
    final repo = await ref.watch(journalRepositoryProvider.future);
    return repo.getAll();
  }

  Future<void> save(JournalEntry entry, List<String> tags) async {
    final repo = await ref.read(journalRepositoryProvider.future);
    if (entry.id == null) {
      await repo.insert(entry, tags);
    } else {
      await repo.update(entry, tags);
    }
    ref.invalidate(tagProvider);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    final repo = await ref.read(journalRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(int id) async {
    final current = state.valueOrNull?.firstWhereOrNull((e) => e.id == id);
    if (current == null) return;
    final repo = await ref.read(journalRepositoryProvider.future);
    await repo.setFavorite(id, !current.isFavorite);
    ref.invalidateSelf();
  }
}
