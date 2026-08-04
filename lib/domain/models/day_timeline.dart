import 'habit.dart';
import 'journal_entry.dart';
import 'mood.dart';
import 'note.dart';

/// Everything that happened on a single day, aggregated for the timeline.
///
/// Produced by `TimelineBuilder` from the app's source data. Only days with
/// at least one journal entry, note or done habit appear in the timeline.
class DayTimeline {
  const DayTimeline({
    required this.date,
    this.journal,
    this.notes = const [],
    this.doneHabits = const [],
  });

  final DateTime date;

  /// The journal entry written that day, if any (at most one per day).
  final JournalEntry? journal;

  final List<Note> notes;
  final List<Habit> doneHabits;

  bool get hasActivity =>
      journal != null || notes.isNotEmpty || doneHabits.isNotEmpty;

  /// Mood shown for the day: the entry's mood when journaled.
  Mood? get mood => journal?.mood;

  /// One-line summary used by timeline cards: e.g.
  /// `😄 Journaled · 2/4 habits · 1 note`.
  String get quickSummary {
    final parts = <String>[];
    final j = journal;
    if (j != null) parts.add('${j.mood.emoji} ${j.mood.label}');
    if (doneHabits.isNotEmpty) {
      parts.add('${doneHabits.length} habit${doneHabits.length == 1 ? '' : 's'} done');
    }
    if (notes.isNotEmpty) {
      parts.add('${notes.length} note${notes.length == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }
}
