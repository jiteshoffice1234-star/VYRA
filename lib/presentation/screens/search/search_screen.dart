import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/habits/habit_providers.dart';
import '../../../application/journal/journal_providers.dart';
import '../../../application/notes/note_providers.dart';
import '../../../application/search/search_providers.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../core/widgets/highlighted_text.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/search_result.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus();
    // The query provider outlives the screen (it is not autoDispose), so
    // reset it on every open to avoid showing stale results with an empty
    // search field.
    ref.read(searchQueryProvider.notifier).clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _query => ref.watch(searchQueryProvider).trim();

  void _setQuery(String value) {
    ref.read(searchQueryProvider.notifier).update(value);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _setQuery,
          onSubmitted: (v) => ref.read(searchHistoryProvider.notifier).add(v),
          decoration: const InputDecoration(
            hintText: 'Search everything…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).clear();
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: query.isEmpty
          ? _HistoryView(
              onPick: (q) {
                _controller.text = q;
                _controller.selection = TextSelection.collapsed(offset: q.length);
                _setQuery(q);
              },
            )
          : _ResultsView(
              query: query,
              onOpen: _openResult,
            ),
    );
  }

  void _openResult(UniversalSearchResult result) {
    ref.read(searchHistoryProvider.notifier).add(ref.read(searchQueryProvider));
    switch (result.type) {
      case SearchItemType.journal:
        context.push('/journal/detail/${result.id}');
      case SearchItemType.note:
        context.push('/note/detail/${result.id}');
      case SearchItemType.habit:
        context.push('/habit/detail/${result.id}');
      case SearchItemType.category:
        final kind = result.categoryKind ?? CategoryKind.note;
        if (kind == CategoryKind.habit) {
          ref.read(habitCategoryFilterProvider.notifier).state = result.id;
          context.go('/habits');
        } else {
          ref.read(noteCategoryFilterProvider.notifier).state = result.id;
          context.go('/notes');
        }
      case SearchItemType.tag:
        ref.read(journalSearchProvider.notifier).state = result.title;
        context.go('/journal');
    }
  }
}

class _HistoryView extends ConsumerWidget {
  const _HistoryView({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        AppLogger.error('Failed to load search history', e, st);
        return AppEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load recent searches',
          subtitle: 'Something went wrong while reading your history.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(searchHistoryProvider),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            icon: Icons.search,
            title: 'Search everything',
            subtitle:
                'Journals, notes, habits, categories and tags — all in one place.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppSectionHeader(
              title: 'Recent searches',
              trailing: TextButton(
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).clear(),
                child: const Text('Clear all'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.history,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        items[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => ref
                            .read(searchHistoryProvider.notifier)
                            .remove(items[i]),
                      ),
                      onTap: () => onPick(items[i]),
                    ),
                    if (i != items.length - 1)
                      Divider(height: 1, indent: 56, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<UniversalSearchResult> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final activeTypes = ref.watch(searchTypeFilterProvider);
    final sortNewest = ref.watch(searchSortNewestProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              FilterPill(
                label: 'All',
                icon: Icons.apps,
                selected: activeTypes.length == SearchItemType.values.length,
                onTap: () => ref
                    .read(searchTypeFilterProvider.notifier)
                    .state = SearchItemType.values.toSet(),
              ),
              for (final type in SearchItemType.values)
                FilterPill(
                  label: _typeLabel(type),
                  icon: _typeIcon(type),
                  selected: activeTypes.contains(type),
                  onTap: () {
                    final next = {...activeTypes};
                    if (!next.add(type)) next.remove(type);
                    ref.read(searchTypeFilterProvider.notifier).state = next;
                  },
                ),
              const SizedBox(width: 4),
              FilterPill(
                label: sortNewest ? 'Newest' : 'Relevance',
                icon: sortNewest ? Icons.schedule : Icons.trending_up,
                selected: false,
                onTap: () => ref
                    .read(searchSortNewestProvider.notifier)
                    .state = !sortNewest,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) {
              AppLogger.error('Search failed', e, st);
              return AppEmptyState(
                icon: Icons.error_outline,
                title: 'Search failed',
                subtitle: 'Something went wrong. Try again.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(searchResultsProvider),
              );
            },
            data: (list) {
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.search_off,
                  title: 'No results',
                  subtitle: 'Nothing matches “$query”. Try different words.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final result = list[index];
                  return _ResultTile(
                    result: result,
                    query: query,
                    onTap: () => onOpen(result),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  final UniversalSearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final color = _typeColor(result.type);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(style.radius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(style.radius),
                ),
                child: Icon(_typeIcon(result.type), size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(
                      text: result.title,
                      query: query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (result.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      HighlightedText(
                        text: result.subtitle,
                        query: query,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _typeLabel(result.type),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(SearchItemType type) => switch (type) {
      SearchItemType.journal => 'Journal',
      SearchItemType.note => 'Note',
      SearchItemType.habit => 'Habit',
      SearchItemType.category => 'Category',
      SearchItemType.tag => 'Tag',
    };

IconData _typeIcon(SearchItemType type) => switch (type) {
      SearchItemType.journal => Icons.menu_book,
      SearchItemType.note => Icons.sticky_note_2,
      SearchItemType.habit => Icons.repeat,
      SearchItemType.category => Icons.folder_outlined,
      SearchItemType.tag => Icons.tag,
    };

Color _typeColor(SearchItemType type) => switch (type) {
      SearchItemType.journal => const Color(0xFF6C5CE7),
      SearchItemType.note => const Color(0xFFF59E0B),
      SearchItemType.habit => const Color(0xFF10B981),
      SearchItemType.category => const Color(0xFF0EA5E9),
      SearchItemType.tag => const Color(0xFFEC4899),
    };
