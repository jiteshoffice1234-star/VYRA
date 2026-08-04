import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/day_timeline.dart';
import '../../domain/services/timeline_builder.dart';
import '../habits/habit_providers.dart';
import '../journal/journal_providers.dart';
import '../notes/note_providers.dart';

/// The complete daily history, newest first.
///
/// Watches the source list providers (which reload after any save / delete /
/// toggle), so the timeline stays in sync automatically. Habit counts come
/// from a single grouped query, exactly like the dashboard.
final timelineProvider = FutureProvider<List<DayTimeline>>((ref) async {
  final journals = await ref.watch(journalListProvider.future);
  final notes = await ref.watch(notesProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final counts = await ref.watch(habitCountsMapProvider.future);

  return TimelineBuilder.build(
    journals: journals,
    notes: notes,
    habits: habits,
    countsGrouped: counts,
  );
});
