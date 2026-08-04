import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/timeline/timeline_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/mood_colors.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../domain/models/day_timeline.dart';
import '../../../domain/models/habit.dart';
import '../../../domain/models/journal_entry.dart';
import '../../../domain/models/mood.dart';
import '../../../domain/models/note.dart';

/// Batch of days revealed each time the user scrolls near the end.
const int _timelinePageSize = 30;

/// The complete daily history: date, mood, journal, done habits, notes.
///
/// Infinite scrolling is done in the widget layer — the provider builds the
/// full (already compact) day list once, and this screen reveals it in
/// pages so rendering stays cheap no matter how much history exists.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final ScrollController _scroll = ScrollController();
  DateTime? _visibleMonth;
  int _visibleCount = _timelinePageSize;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadMore();
    }
    // Keep the month strip in sync with what is on screen.
    final month = _monthAtScrollOffset(pos.pixels);
    if (month != null && !AppDate.isSameMonth(month, _visibleMonth ?? month)) {
      setState(() => _visibleMonth = month);
    }
  }

  /// Best-effort month under the top of the viewport, using average card
  /// height over the metrics that are already laid out.
  DateTime? _monthAtScrollOffset(double offset) {
    final days = ref.read(timelineProvider).valueOrNull ?? const <DayTimeline>[];
    if (days.isEmpty) return null;
    // Fall back to a plain estimate when metrics are unavailable.
    final rendered = _visibleCount.clamp(1, 999999);
    final average = _scroll.position.viewportDimension > 0
        ? (_scroll.position.maxScrollExtent / rendered)
        : 0;
    final estIndex =
        average > 0 ? (offset / average).floor().clamp(0, days.length - 1) : 0;
    return DateTime(days[estIndex].date.year, days[estIndex].date.month);
  }

  void _loadMore() {
    final days = ref.read(timelineProvider).valueOrNull ?? const <DayTimeline>[];
    if (_visibleCount >= days.length) return;
    setState(() {
      _visibleCount = (_visibleCount + _timelinePageSize).clamp(
        0,
        days.length,
      );
    });
  }

  Future<void> _jumpTo(DateTime target) async {
    final days = ref.read(timelineProvider).valueOrNull ?? const <DayTimeline>[];
    if (days.isEmpty) return;

    final anchor = AppDate.startOfDay(target);
    // The anchor may not have activity; find the nearest day at or before it.
    var index = 0;
    for (var i = 0; i < days.length; i++) {
      if (days[i].date.isBefore(anchor) || AppDate.isSameDay(days[i].date, anchor)) {
        index = i;
      } else {
        break;
      }
    }
    setState(() {
      _visibleCount = (_visibleCount > index + 1)
          ? _visibleCount
          : (index + 1).clamp(0, days.length);
      _visibleMonth = DateTime(target.year, target.month);
    });

    // Reveal the requested month after the new items are laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final estAvg = days.isEmpty ? 0.0 : _scroll.position.maxScrollExtent / days.length;
      final offset = (index * estAvg).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _pickMonth() async {
    final days = ref.read(timelineProvider).valueOrNull ?? const <DayTimeline>[];
    if (days.isEmpty) return;
    final oldest = days.last.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonth ?? DateTime.now(),
      firstDate: DateTime(oldest.year, oldest.month, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) _jumpTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineProvider);

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
                    'Timeline',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          timeline.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(
              child: AppEmptyState(
                icon: Icons.error_outline,
                title: 'Could not load your timeline',
                subtitle: '$e',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(timelineProvider),
              ),
            ),
            data: (days) {
              if (days.isEmpty) {
                return Expanded(
                  child: AppEmptyState(
                    icon: Icons.timeline,
                    title: 'Your story starts today',
                    subtitle:
                        'Journal entries, notes and completed habits will '
                        'appear here, day by day.',
                    actionLabel: 'Write an entry',
                    onAction: () => context.push('/journal/editor'),
                  ),
                );
              }
              return Expanded(
                child: Column(
                  children: [
                    _MonthStrip(
                      visibleMonth: _visibleMonth,
                      onPrev: () => _shiftMonth(days, -1),
                      onNext: () => _shiftMonth(days, 1),
                      onJump: _pickMonth,
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.pagePadding,
                          8,
                          AppConstants.pagePadding,
                          24,
                        ),
                        itemCount: days.length + 1,
                        itemBuilder: (context, index) {
                          if (index == days.length) {
                            return _visibleCount < days.length
                                ? const _LoadingMoreIndicator()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Center(
                                      child: Text(
                                        '${days.length} days of history',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  );
                          }
                          if (index >= _visibleCount) {
                            return const SizedBox.shrink();
                          }
                          final day = days[index];
                          final firstOfMonth =
                              index == 0 ||
                                  !AppDate.isSameMonth(
                                    day.date,
                                    days[index - 1].date,
                                  );
                          return _DayCard(
                            day: day,
                            showMonthHeader: firstOfMonth,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _shiftMonth(List<DayTimeline> days, int delta) {
    if (days.isEmpty) return;
    final base = _visibleMonth ?? days.first.date;
    final target = DateTime(base.year, base.month + delta, 1);
    _jumpTo(target);
  }
}

/// Prev / next month + calendar jump strip above the timeline.
class _MonthStrip extends StatelessWidget {
  const _MonthStrip({
    required this.visibleMonth,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  final DateTime? visibleMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = visibleMonth == null
        ? 'This month'
        : AppDate.monthYear(visibleMonth!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onJump,
            tooltip: 'Jump to month',
            icon: Icon(Icons.calendar_month, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

/// One day in the timeline: date header + mood, journal, done habits, notes.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.showMonthHeader});

  final DayTimeline day;
  final bool showMonthHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final date = day.date;
    final isToday = AppDate.isToday(date);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMonthHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Row(
                children: [
                  Text(
                    AppDate.monthYear(date),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Divider(color: scheme.outlineVariant)),
                ],
              ),
            ),
          ],
          Card(
            child: InkWell(
              onTap: () => _openDay(context),
              borderRadius: BorderRadius.circular(style.radius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateHeader(date: date, isToday: isToday, mood: day.mood),
                    const SizedBox(height: 12),
                    if (day.journal != null)
                      _JournalBlock(entry: day.journal!),
                    if (day.doneHabits.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _HabitsBlock(habits: day.doneHabits),
                    ],
                    if (day.notes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _NotesBlock(notes: day.notes),
                    ],
                    const SizedBox(height: 10),
                    _SummaryLine(summary: day.quickSummary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDay(BuildContext context) {
    final entry = day.journal;
    if (entry != null) {
      if (entry.id != null) context.push('/journal/detail/${entry.id}');
      return;
    }
    if (day.notes.isNotEmpty && day.notes.first.id != null) {
      context.push('/note/detail/${day.notes.first.id}');
      return;
    }
    if (day.doneHabits.isNotEmpty && day.doneHabits.first.id != null) {
      context.push('/habit/detail/${day.doneHabits.first.id}');
    }
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.isToday, this.mood});

  final DateTime date;
  final bool isToday;
  final Mood? mood;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final relative = isToday
        ? 'Today'
        : AppDate.isSameDay(date, AppDate.addDays(DateTime.now(), -1))
            ? 'Yesterday'
            : null;

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isToday ? scheme.primary : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isToday
                          ? scheme.onPrimary
                          : scheme.onPrimaryContainer,
                      height: 1,
                    ),
              ),
              Text(
                AppDate.weekdayLetter(date).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? scheme.onPrimary.withValues(alpha: 0.85)
                          : scheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                relative ?? AppDate.formatFull(date),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                AppDate.formatMedium(date),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (mood != null) Text(mood!.emoji, style: const TextStyle(fontSize: 26)),
      ],
    );
  }
}

class _JournalBlock extends StatelessWidget {
  const _JournalBlock({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final color = entry.mood.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(style.radius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                entry.mood.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (entry.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              TextUtil.excerpt(entry.content, maxChars: 140),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _HabitsBlock extends StatelessWidget {
  const _HabitsBlock({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final habit in habits)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppConstants.habitIcons[
                      habit.iconIndex % AppConstants.habitIcons.length],
                  size: 14,
                  color: Color(habit.color),
                ),
                const SizedBox(width: 6),
                Text(
                  habit.name,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 13, color: const Color(0xFF10B981)),
              ],
            ),
          ),
      ],
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = notes.take(2).toList();
    return Column(
      children: [
        for (final note in preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Color(note.color).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    note.type == NoteType.text
                        ? Icons.sticky_note_2
                        : Icons.checklist,
                    size: 13,
                    color: Color(note.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        note.type == NoteType.text
                            ? TextUtil.excerpt(note.content, maxChars: 80)
                            : '${note.checkedCount}/${note.items.length} tasks done',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (notes.length > 2)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              '+${notes.length - 2} more note${notes.length - 2 == 1 ? '' : 's'}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (summary.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 13, color: scheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
