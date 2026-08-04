import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/journal/journal_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/debounce.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../core/widgets/month_calendar.dart';
import '../../../domain/models/journal_entry.dart';
import '../../widgets/journal_card.dart';

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  bool _showCalendar = false;
  final Debouncer _searchDebounce = Debouncer();

  /// Entry id → word count, computed once per entry so the list header's
  /// "N entries · M words" line stays cheap no matter how many entries or
  /// how often the filter rebuilds it.
  final Map<int, int> _wordCountCache = {};

  /// Identity of the last journal list we cached word counts for. When the
  /// list is reloaded (edit / delete), ids stay the same but content may
  /// change, so the cache must be dropped.
  List<JournalEntry>? _cachedList;

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      _searchDebounce.flush(
        () => ref.read(journalSearchProvider.notifier).state = '',
      );
      return;
    }
    _searchDebounce.run(
      () => ref.read(journalSearchProvider.notifier).state = value,
    );
  }

  /// Word count for the filtered list, caching per-entry counts.
  int _wordCountOf(List<JournalEntry> entries) {
    final all = ref.watch(journalListProvider).valueOrNull ?? const [];
    if (!identical(_cachedList, all)) {
      _cachedList = all;
      _wordCountCache.clear();
    }
    var total = 0;
    for (final e in entries) {
      final id = e.id;
      if (id == null) {
        total += TextUtil.wordCount(e.content);
      } else {
        total += _wordCountCache.putIfAbsent(id, () => TextUtil.wordCount(e.content));
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = ref.watch(filteredJournalListProvider);
    final all = ref.watch(journalListProvider).valueOrNull ?? const [];
    final search = ref.watch(journalSearchProvider);
    final dateFilter = ref.watch(journalDateProvider);
    final favoritesOnly = ref.watch(journalFavoritesOnlyProvider);
    final newest = ref.watch(journalSortNewestProvider);

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
                    'Journal',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search entries, tags…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // Cancel any pending debounce so a stale query is
                          // not re-applied after the field is cleared.
                          _searchDebounce.cancel();
                          ref.read(journalSearchProvider.notifier).state = '';
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
                    padding: EdgeInsets.zero,
                    label: dateFilter == null
                        ? 'All dates'
                        : AppDate.formatShort(dateFilter),
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                    onClear: dateFilter == null
                        ? null
                        : () =>
                            ref.read(journalDateProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    padding: EdgeInsets.zero,
                    label: 'Favorites',
                    icon: Icons.star,
                    selected: favoritesOnly,
                    onTap: () => ref
                        .read(journalFavoritesOnlyProvider.notifier)
                        .state = !favoritesOnly,
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    padding: EdgeInsets.zero,
                    label: newest ? 'Newest' : 'Oldest',
                    icon: newest ? Icons.arrow_downward : Icons.arrow_upward,
                    onTap: () => ref
                        .read(journalSortNewestProvider.notifier)
                        .state = !newest,
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    padding: EdgeInsets.zero,
                    label: 'Calendar',
                    icon: Icons.calendar_view_month,
                    selected: _showCalendar,
                    onTap: () => setState(() => _showCalendar = !_showCalendar),
                  ),
                ],
              ),
            ),
          ),
          if (_showCalendar)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: MonthCalendar(
                    month: DateTime.now(),
                    primaryDays: {
                      for (final e in all) AppDate.dayKey(e.entryDate),
                    },
                    selectedDay: dateFilter,
                    onSelectDay: (day) {
                      ref.read(journalDateProvider.notifier).state = day;
                      setState(() => _showCalendar = false);
                    },
                  ),
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
                onAction: () => ref.invalidate(journalListProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  final hasFilters = search.isNotEmpty ||
                      dateFilter != null ||
                      favoritesOnly;
                  return hasFilters
                      ? AppEmptyState(
                          icon: Icons.search_off,
                          title: 'No matches',
                          subtitle: 'Try a different search or clear the filters.',
                        )
                      : AppEmptyState(
                          icon: Icons.menu_book,
                          title: 'No journal entries yet',
                          subtitle: 'Capture your thoughts and reflect on the day.',
                          actionLabel: 'Write entry',
                          onAction: () => context.push('/journal/editor'),
                        );
                }
                final totalWords = _wordCountOf(entries);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: entries.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${entries.length} entries · $totalWords words',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      );
                    }
                    final entry = entries[index - 1];
                    return JournalCard(
                      entry: entry,
                      onTap: () => context.push('/journal/detail/${entry.id}'),
                      onFavoriteToggle: () => _toggleFavorite(entry),
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

  Future<void> _toggleFavorite(JournalEntry entry) async {
    try {
      await ref.read(journalListProvider.notifier).toggleFavorite(entry.id!);
    } catch (e, st) {
      AppLogger.error('Failed to toggle journal favorite', e, st);
      if (mounted) showAppSnackBar(context, 'Could not update the entry.');
    }
  }

  Future<void> _pickDate() async {
    final current = ref.read(journalDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      ref.read(journalDateProvider.notifier).state = picked;
    }
  }
}

