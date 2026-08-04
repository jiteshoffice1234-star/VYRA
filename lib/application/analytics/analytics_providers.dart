import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/habit.dart';
import '../../domain/services/analytics_service.dart';
import '../categories/category_providers.dart';
import '../habits/habit_providers.dart';
import '../journal/journal_providers.dart';
import '../notes/note_providers.dart';
import '../providers/app_providers.dart';

/// Everything the analytics screen needs, recomputed whenever journals,
/// notes, habits or categories change (like the dashboard and timeline).
final analyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  final journals = await ref.watch(journalListProvider.future);
  final notes = await ref.watch(notesProvider.future);
  // Analytics counts every habit ever tracked — archived ones included — so
  // historical stats stay truthful.
  final habitRepo = await ref.watch(habitRepositoryProvider.future);
  final habits = await habitRepo.getAll(includeArchived: true);
  final categories = await ref.watch(categoriesProvider.future);
  final counts = await ref.watch(habitCountsMapProvider.future);

  return AnalyticsService.compute(
    journals: journals,
    notes: notes,
    habits: habits,
    categories: categories,
    counts: counts,
  );
});
