import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/list_utils.dart';
import '../../domain/models/note.dart';
import '../providers/app_providers.dart';
import '../tags/tag_providers.dart';

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

/// Search / filter state.
final noteSearchProvider = StateProvider<String>((ref) => '');
final notePinnedOnlyProvider = StateProvider<bool>((ref) => false);
final noteFavoritesOnlyProvider = StateProvider<bool>((ref) => false);
final noteCategoryFilterProvider = StateProvider<int?>((ref) => null);

/// Filtered notes derived from [notesProvider].
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final query = ref.watch(noteSearchProvider).trim().toLowerCase();
  final pinnedOnly = ref.watch(notePinnedOnlyProvider);
  final favoritesOnly = ref.watch(noteFavoritesOnlyProvider);
  final categoryId = ref.watch(noteCategoryFilterProvider);

  return ref.watch(notesProvider).whenData((notes) {
    final filtered = notes.where((n) {
      if (query.isNotEmpty &&
          !n.title.toLowerCase().contains(query) &&
          !n.content.toLowerCase().contains(query) &&
          !n.tags.any((t) => t.toLowerCase().contains(query))) {
        return false;
      }
      if (pinnedOnly && !n.isPinned) return false;
      if (favoritesOnly && !n.isFavorite) return false;
      if (categoryId != null && n.categoryId != categoryId) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered;
  });
});

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repo = await ref.watch(noteRepositoryProvider.future);
    return repo.getAll();
  }

  Future<void> save(Note note, List<String> tags) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    if (note.id == null) {
      await repo.insert(note, tags);
    } else {
      await repo.update(note, tags);
    }
    ref.invalidate(tagProvider);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
  }

  Future<void> togglePin(int id) async {
    final current = state.valueOrNull?.firstWhereOrNull((n) => n.id == id);
    if (current == null) return;
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.setPinned(id, !current.isPinned);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(int id) async {
    final current = state.valueOrNull?.firstWhereOrNull((n) => n.id == id);
    if (current == null) return;
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.setFavorite(id, !current.isFavorite);
    ref.invalidateSelf();
  }
}
