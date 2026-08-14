import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/analytics/week_review_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/mood_colors.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../domain/services/analytics_service.dart';
import '../../../domain/services/week_review.dart';

/// "This Week": completion, best day, mood trend, streak changes and a
/// generated summary — all computed from local data via [WeekReviewService].
class WeekReviewScreen extends ConsumerWidget {
  const WeekReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(weekReviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('This Week')),
      body: SafeArea(
        child: review.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load your week',
            subtitle: '$e',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(weekReviewProvider),
          ),
          data: (r) {
            if (r.totalHabits == 0 && r.journalCount == 0) {
              return AppEmptyState(
                icon: Icons.auto_awesome,
                title: 'No activity this week yet',
                subtitle: 'Add a habit or write a journal entry and your '
                    'week review will build itself.',
                actionLabel: 'Write an entry',
                onAction: () => context.push('/journal/editor'),
              );
            }
            return _WeekReviewView(review: r);
          },
        ),
      ),
    );
  }
}

class _WeekReviewView extends StatelessWidget {
  const _WeekReviewView({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        12,
        AppConstants.pagePadding,
        32,
      ),
      children: [
        _Header(review: review),
        const SizedBox(height: 16),
        _SummaryCard(review: review),
        const SizedBox(height: 12),
        _StatRow(review: review),
        const SizedBox(height: 24),
        AppSectionHeader(title: 'Habits done per day'),
        const SizedBox(height: 10),
        _WeekBarsCard(review: review),
        const SizedBox(height: 24),
        AppSectionHeader(title: 'Mood trend'),
        const SizedBox(height: 10),
        _MoodCard(stats: review.moodStats),
        const SizedBox(height: 24),
        AppSectionHeader(title: 'Streaks'),
        const SizedBox(height: 10),
        _StreakCard(review: review),
        if (review.habitStats.isNotEmpty) ...[
          const SizedBox(height: 24),
          AppSectionHeader(title: 'Habit completion'),
          const SizedBox(height: 10),
          _HabitsCard(review: review),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final range = '${AppDate.formatShort(review.start)} – '
        '${AppDate.formatShort(review.end)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your week in review',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                range,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Icon(Icons.auto_awesome, size: 30, color: scheme.primary),
      ],
    );
  }
}

/// The generated prose summary of the week.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.tertiary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(style.radius),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Summary',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.check_circle,
            color: const Color(0xFF6C5CE7),
            value: review.weekCompletion * 100,
            suffix: '%',
            label: 'Week completion',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.menu_book,
            color: const Color(0xFFF59E0B),
            value: review.journalCount.toDouble(),
            label: 'Journals',
          ),
        ),
      ],
    );
  }
}

/// Best day + a 7-day bar chart of habits done each day.
class _WeekBarsCard extends StatelessWidget {
  const _WeekBarsCard({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final day = review.bestDay;
    final maxCount = review.doneByDay.fold<int>(1, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: style.hardShadow != null ? [style.hardShadow!] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: const Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  day == null
                      ? 'Nothing done yet this week'
                      : 'Best day: ${AppDate.weekdayName(day)} '
                          '(${review.bestDayCount} habit'
                          '${review.bestDayCount == 1 ? '' : 's'})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < review.doneByDay.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Text(
                          '${review.doneByDay[i]}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          height: 56 * (review.doneByDay[i] / maxCount),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppDate.weekdayLetter(
                            AppDate.addDays(review.start, i),
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.stats});

  final List<MoodStat> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(style.radius),
          border: style.boxBorder ??
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Journal entries with moods will appear here.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    final maxCount = stats.fold<int>(1, (m, s) => s.count > m ? s.count : m);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: style.hardShadow != null ? [style.hardShadow!] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in stats.take(5)) ...[
            Row(
              children: [
                Text(s.mood.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.mood.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${s.count}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (s.count / maxCount).clamp(0.0, 1.0),
                minHeight: 7,
                color: s.mood.color,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final delta = review.streakDelta;
    final color = delta > 0
        ? const Color(0xFF10B981)
        : delta < 0
            ? const Color(0xFFF43F5E)
            : scheme.onSurfaceVariant;
    final line = delta > 0
        ? '+$delta this week'
        : delta < 0
            ? '$delta this week'
            : 'no change';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: style.hardShadow != null ? [style.hardShadow!] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              delta >= 0 ? Icons.local_fire_department : Icons.water_drop,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.currentStreak > 0
                      ? '${review.currentStreak} day'
                          '${review.currentStreak == 1 ? '' : 's'} streak'
                      : 'No streak yet',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  review.streakWeekAgo > 0
                      ? 'was $line · ${review.streakWeekAgo} day'
                          '${review.streakWeekAgo == 1 ? '' : 's'} last week'
                      : 'best current streak across your habits',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (review.currentStreak > 0)
            Text(
              line,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
        ],
      ),
    );
  }
}

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.review});

  final WeekReview review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: style.hardShadow != null ? [style.hardShadow!] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${review.onTrackHabits} of ${review.totalHabits} habits '
                  'on track',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${(review.weekCompletion * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final s in review.habitStats.take(5)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${s.doneDays}/${s.totalDays} days',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(s.rate * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Color(s.habit.color),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: s.rate.clamp(0.0, 1.0),
                minHeight: 8,
                color: Color(s.habit.color),
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
