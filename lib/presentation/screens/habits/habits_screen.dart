import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/categories/category_providers.dart';
import '../../application/habits/habit_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/vyra_style.dart';
import '../../core/utils/debounce.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/filter_pill.dart';
import '../../domain/models/category.dart';
import '../../domain/models/habit.dart';
import '../../domain/services/habit_stats.dart';
import '../../widgets/habit_check.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final Debouncer _searchDebounce = Debouncer();

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      _searchDebounce.flush(
        () => ref.read(habitSearchProvider.notifier).state = '',
      );
      return;
    }
    _searchDebounce.run(
      () => ref.read(habitSearchProvider.notifier).state = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = ref.watch(filteredHabitsProvider);
    final search = ref.watch(habitSearchProvider);
    final typeFilter = ref.watch(habitTypeFilterProvider);
    final categoryFilter = ref.watch(habitCategoryFilterProvider);
    final showArchived = ref.watch(habitShowArchivedProvider);
    final categories =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
            .where((c) => c.kind == CategoryKind.habit)
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
                    'Habits',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Good & bad',
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
                hintText: 'Search habits…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          // Cancel any pending debounce so a stale query is
                          // not re-applied after the field is cleared.
                          _searchDebounce.cancel();
                          ref.read(habitSearchProvider.notifier).state = '';
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
                    label: showArchived ? 'Active' : 'Archived',
                    icon: Icons.archive_outlined,
                    selected: showArchived,
                    onTap: () => ref
                        .read(habitShowArchivedProvider.notifier)
                        .state = !showArchived,
                  ),
                  FilterPill(
                    label: 'All',
                    selected: typeFilter == 'all',
                    onTap: () =>
                        ref.read(habitTypeFilterProvider.notifier).state = 'all',
                  ),
                  FilterPill(
                    label: 'Good',
                    icon: Icons.add_circle_outline,
                    selected: typeFilter == 'good',
                    onTap: () =>
                        ref.read(habitTypeFilterProvider.notifier).state = 'good',
                  ),
                  FilterPill(
                    label: 'Bad',
                    icon: Icons.remove_circle_outline,
                    selected: typeFilter == 'bad',
                    onTap: () =>
                        ref.read(habitTypeFilterProvider.notifier).state = 'bad',
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    for (final category in categories)
                      FilterPill(
                        label: category.name,
                        selected: categoryFilter == category.id,
                        onTap: () => ref
                            .read(habitCategoryFilterProvider.notifier)
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
                onAction: () => ref.invalidate(habitsProvider),
              ),
              data: (habits) {
                if (habits.isEmpty) {
                  final hasFilters = search.isNotEmpty ||
                      typeFilter != 'all' ||
                      categoryFilter != null;
                  return hasFilters
                      ? AppEmptyState(
                          icon: Icons.search_off,
                          title: 'No matches',
                          subtitle: 'Try a different search or clear the filters.',
                        )
                      : showArchived
                          ? AppEmptyState(
                              icon: Icons.archive_outlined,
                              title: 'No archived habits',
                              subtitle: 'Archive a habit to tidy up your list.',
                            )
                          : AppEmptyState(
                              icon: Icons.repeat,
                              title: 'No habits yet',
                              subtitle: 'Build good habits and break bad ones.',
                              actionLabel: 'New habit',
                              onAction: () => context.push('/habit/editor'),
                            );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: habits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _HabitCard(habit: habits[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});

  final Habit habit;

  Future<void> _toggleToday(WidgetRef ref) async {
    try {
      await ref.read(habitsProvider.notifier).toggleToday(habit);
    } catch (e, st) {
      AppLogger.error('Failed to toggle habit', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not update the habit.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final color = Color(habit.color);
    final counts = ref.watch(habitCountsProvider(habit.id));
    final streak = HabitStats.currentStreak(habit, counts);

    return Card(
      child: InkWell(
        onTap: () => context.push('/habit/detail/${habit.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(style.radius),
                    ),
                    child: Icon(
                      AppConstants.habitIcons[
                          habit.iconIndex % AppConstants.habitIcons.length],
                      size: 22,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          habit.archived
                              ? 'Archived'
                              : (habit.categoryName ??
                                  (habit.type == HabitType.good
                                      ? 'Good habit'
                                      : 'Bad habit')),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (habit.archived)
                    Icon(
                      Icons.archive_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    )
                  else
                    HabitCheck(
                      habit: habit,
                      onChanged: () => _toggleToday(ref),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (streak > 0) ...[
                    Icon(Icons.local_fire_department,
                        size: 15, color: const Color(0xFFF97316)),
                    const SizedBox(width: 4),
                    Text(
                      '${TextUtil.plural(streak, 'day')} streak',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: const Color(0xFFF97316),
                              fontWeight: FontWeight.w700),
                    ),
                  ] else ...[
                    Icon(Icons.flag_outlined,
                        size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Streak starts today',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  if (habit.type == HabitType.good)
                    Text(
                      'Target ${habit.targetPerDay}/day',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
