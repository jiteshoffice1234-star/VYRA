import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/week_review.dart';
import '../habits/habit_providers.dart';
import '../journal/journal_providers.dart';
import '../providers/app_providers.dart';

/// The trailing-7-day review for the "This Week" screen, recomputed whenever
/// journals, habits or counts change. Uses the same sources as the analytics
/// screen (archived habits included, so historical stats stay truthful).
final weekReviewProvider = FutureProvider<WeekReview>((ref) async {
  final journals = await ref.watch(journalListProvider.future);
  final habitRepo = await ref.watch(habitRepositoryProvider.future);
  final habits = await habitRepo.getAll(includeArchived: true);
  final counts = await ref.watch(habitCountsMapProvider.future);

  return WeekReviewService.build(
    journals: journals,
    habits: habits,
    counts: counts,
  );
});
