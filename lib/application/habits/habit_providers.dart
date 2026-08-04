import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/habit.dart';
import '../../domain/services/habit_stats.dart';
import '../providers/app_providers.dart';

final habitsProvider =
    AsyncNotifierProvider<HabitsNotifier, List<Habit>>(HabitsNotifier.new);

/// Search / filter state.
final habitSearchProvider = StateProvider<String>((ref) => '');
final habitTypeFilterProvider = StateProvider<String>((ref) => 'all');
final habitCategoryFilterProvider = StateProvider<int?>((ref) => null);

/// When true the habits list shows archived habits instead of active ones.
final habitShowArchivedProvider = StateProvider<bool>((ref) => false);

/// All habit day counts in one grouped query, shared by every consumer
/// (check buttons, detail screens, dashboard, timeline, analytics). Loading
/// once and deriving per-habit views from this map avoids N separate SQL
/// queries every time a screen with check buttons is built.
final habitCountsMapProvider =
    FutureProvider<Map<int, Map<String, int>>>((ref) async {
  final repo = await ref.watch(habitRepositoryProvider.future);
  return repo.countsGrouped();
});

/// Per-habit day counts, derived from [habitCountsMapProvider].
///
/// Synchronous (empty map while loading) so list rows render immediately
/// without firing a per-habit database query.
final habitCountsProvider =
    Provider.family<Map<String, int>, int>((ref, habitId) {
  return ref.watch(habitCountsMapProvider).valueOrNull?[habitId] ??
      const <String, int>{};
});

/// Filtered habit list derived from [habitsProvider].
final filteredHabitsProvider = Provider<AsyncValue<List<Habit>>>((ref) {
  final query = ref.watch(habitSearchProvider).trim().toLowerCase();
  final type = ref.watch(habitTypeFilterProvider);
  final categoryId = ref.watch(habitCategoryFilterProvider);

  return ref.watch(habitsProvider).whenData((habits) {
    return habits.where((h) {
      if (query.isNotEmpty &&
          !h.name.toLowerCase().contains(query) &&
          !h.description.toLowerCase().contains(query)) {
        return false;
      }
      if (type != 'all' && h.type.id != type) return false;
      if (categoryId != null && h.categoryId != categoryId) return false;
      return true;
    }).toList();
  });
});

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  /// Habit ids with an in-flight toggle/adjust so rapid double-taps cannot
  /// race (both reading the same counts and writing stale values).
  final Set<int> _busyIds = {};

  @override
  Future<List<Habit>> build() async {
    final repo = await ref.watch(habitRepositoryProvider.future);
    final showArchived = ref.watch(habitShowArchivedProvider);
    return repo.getAll(includeArchived: showArchived);
  }

  /// Archives or restores a habit. Archiving hides it from the active list
  /// (history is kept); restoring brings it back.
  Future<void> setArchived(Habit habit, bool archived) async {
    final id = habit.id;
    if (id == null) return;
    final repo = await ref.read(habitRepositoryProvider.future);
    await repo.setArchived(id, archived);
    _afterChange();
  }

  Future<void> save(Habit habit) async {
    final repo = await ref.read(habitRepositoryProvider.future);
    if (habit.id == null) {
      await repo.insert(habit);
    } else {
      await repo.update(habit);
    }
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    final repo = await ref.read(habitRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
  }

  /// Checks/unchecks a habit for today.
  Future<void> toggleToday(Habit habit) async {
    final id = habit.id;
    if (id == null || !_busyIds.add(id)) return;
    try {
      final repo = await ref.read(habitRepositoryProvider.future);
      final now = DateTime.now();
      final counts = await repo.countsForHabit(id);
      final done = HabitStats.isDoneOn(habit, counts, now);
      final next = habit.type == HabitType.good
          ? (done ? 0 : habit.targetPerDay)
          : (done ? 1 : 0);
      await repo.setCount(id, now, next);
    } finally {
      _busyIds.remove(id);
      _afterChange();
    }
  }

  /// Adjusts today's count by a delta (min 0).
  Future<void> adjustCount(Habit habit, int delta) async {
    final id = habit.id;
    if (id == null || !_busyIds.add(id)) return;
    try {
      final repo = await ref.read(habitRepositoryProvider.future);
      final counts = await repo.countsForHabit(id);
      final current = counts[AppDate.dayKey(DateTime.now())] ?? 0;
      final next = (current + delta).clamp(0, 999).toInt();
      await repo.setCount(id, DateTime.now(), next);
    } finally {
      _busyIds.remove(id);
      _afterChange();
    }
  }

  /// Counts changed (toggle / adjust) but the habit list itself did not, so
  /// only the grouped counts provider needs invalidating. This avoids a full
  /// habits re-query and lets dependent providers (dashboard, timeline,
  /// analytics, check buttons) update through Riverpod's graph.
  void _afterChange() {
    ref.invalidate(habitCountsMapProvider);
  }
}
