import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/categories/category_providers.dart';
import '../../../application/notes/note_providers.dart';
import '../../../core/utils/debounce.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../domain/models/category.dart';
import '../../widgets/note_card.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final Debouncer _searchDebounce = Debouncer();

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      _searchDebounce.flush(
        () => ref.read(noteSearchProvider.notifier).state = '',
      );
      return;
    }
    _searchDebounce.run(
      () => ref.read(noteSearchProvider.notifier).state = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = ref.watch(filteredNotesProvider);
    final search = ref.watch(noteSearchProvider);
    final pinnedOnly = ref.watch(notePinnedOnlyProvider);
    final favoritesOnly = ref.watch(noteFavoritesOnlyProvider);
    final categoryFilter = ref.watch(noteCategoryFilterProvider);
    final categories =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
            .where((c) => c.kind == CategoryKind.note)
            .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notes',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${ref.watch(notesProvider).valueOrNull?.length ?? 0} notes',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search notes, tags…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // Cancel any pending debounce so a stale query is
                          // not re-applied after the field is cleared.
                          _searchDebounce.cancel();
                          ref.read(noteSearchProvider.notifier).state = '';
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterPill(
                    label: 'Pinned',
                    icon: Icons.push_pin,
                    selected: pinnedOnly,
                    onTap: () =>
                        ref.read(notePinnedOnlyProvider.notifier).state = !pinnedOnly,
                  ),
                  FilterPill(
                    label: 'Favorites',
                    icon: Icons.star,
                    selected: favoritesOnly,
                    onTap: () => ref
                        .read(noteFavoritesOnlyProvider.notifier)
                        .state = !favoritesOnly,
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    for (final category in categories)
                      FilterPill(
                        label: category.name,
                        selected: categoryFilter == category.id,
                        onTap: () => ref
                            .read(noteCategoryFilterProvider.notifier)
                            .state = categoryFilter == category.id ? null : category.id,
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppEmptyState(
                icon: Icons.error_outline,
                title: 'Something went wrong',
                subtitle: '$e',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(notesProvider),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  final hasFilters = search.isNotEmpty ||
                      pinnedOnly ||
                      favoritesOnly ||
                      categoryFilter != null;
                  return hasFilters
                      ? AppEmptyState(
                          icon: Icons.search_off,
                          title: 'No matches',
                          subtitle: 'Try a different search or clear the filters.',
                        )
                      : AppEmptyState(
                          icon: Icons.sticky_note_2,
                          title: 'No notes yet',
                          subtitle: 'Jot down ideas, lists and reminders.',
                          actionLabel: 'New note',
                          onAction: () => context.push('/note/editor'),
                        );
                }
                // Lazy grid: builds only the visible cards, so thousands of
                // notes stay cheap to scroll (the old Wrap built every card).
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return NoteCard(
                      note: note,
                      onTap: () => context.push('/note/detail/${note.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
