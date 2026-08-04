import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/analytics/analytics_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/mood_colors.dart';
import '../../core/theme/vyra_style.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../domain/services/analytics_service.dart';

/// Analytics: habit completion, mood trends, journal frequency, streaks,
/// best day / month, categories and recent activity — all from local data.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  int _windowDays = 30;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsProvider);

    return SafeArea(
      child: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState(
          icon: Icons.insert_chart_outlined,
          title: 'Could not load analytics',
          subtitle: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(analyticsProvider),
        ),
        data: (data) {
          if (data.totalJournals == 0 &&
              data.totalNotes == 0 &&
              data.totalHabits == 0) {
            return AppEmptyState(
              icon: Icons.insights,
              title: 'No data to analyze yet',
              subtitle: 'Write journal entries, add habits and take notes — '
                  'your insights will appear here automatically.',
              actionLabel: 'Write an entry',
              onAction: () => context.push('/journal/editor'),
            );
          }
          return _AnalyticsView(
            data: data,
            entrance: _entrance,
            windowDays: _windowDays,
            onWindowChanged: (d) => setState(() => _windowDays = d),
          );
        },
      ),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView({
    required this.data,
    required this.entrance,
    required this.windowDays,
    required this.onWindowChanged,
  });

  final AnalyticsData data;
  final AnimationController entrance;
  final int windowDays;
  final ValueChanged<int> onWindowChanged;

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
        _Entrance(
          controller: entrance,
          index: 0,
          child: const _Header(),
        ),
        const SizedBox(height: 16),
        _Entrance(
          controller: entrance,
          index: 1,
          child: _StatGrid(data: data),
        ),
        const SizedBox(height: 24),
        _Entrance(
          controller: entrance,
          index: 2,
          child: AppSectionHeader(
            title: 'Habit completion',
            trailing: _WindowSelector(
              days: windowDays,
              onChanged: onWindowChanged,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Entrance(
          controller: entrance,
          index: 3,
          child: _CompletionCard(data: data, windowDays: windowDays),
        ),
        const SizedBox(height: 24),
        _Entrance(
          controller: entrance,
          index: 4,
          child: const AppSectionHeader(title: 'Moods'),
        ),
        const SizedBox(height: 10),
        _Entrance(
          controller: entrance,
          index: 5,
          child: _MoodCard(stats: data.moodStats),
        ),
        const SizedBox(height: 24),
        _Entrance(
          controller: entrance,
          index: 6,
          child: AppSectionHeader(
            title: 'Journal frequency',
            trailing: Text(
              '${data.totalJournals} entries',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Entrance(
          controller: entrance,
          index: 7,
          child: _JournalFrequencyCard(frequency: data.journalFrequency),
        ),
        const SizedBox(height: 24),
        _Entrance(
          controller: entrance,
          index: 8,
          child: _BestCard(data: data),
        ),
        if (data.habitCategoryStats.isNotEmpty ||
            data.noteCategoryStats.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Entrance(
            controller: entrance,
            index: 9,
            child: const AppSectionHeader(title: 'Categories'),
          ),
          const SizedBox(height: 10),
          _Entrance(
            controller: entrance,
            index: 10,
            child: _CategoryCard(data: data),
          ),
        ],
        if (data.recentActivity.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Entrance(
            controller: entrance,
            index: 11,
            child: const AppSectionHeader(title: 'Recent activity'),
          ),
          const SizedBox(height: 10),
          _Entrance(
            controller: entrance,
            index: 12,
            child: _ActivityCard(entries: data.recentActivity),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Your habits and moods, measured.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.insights,
          size: 30,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.menu_book,
                color: const Color(0xFF6C5CE7),
                value: data.totalJournals.toDouble(),
                label: 'Journal entries',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.sticky_note_2,
                color: const Color(0xFFF59E0B),
                value: data.totalNotes.toDouble(),
                label: 'Notes',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.repeat,
                color: const Color(0xFF10B981),
                value: data.totalHabits.toDouble(),
                label: 'Habits tracked',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.local_fire_department,
                color: const Color(0xFFF97316),
                value: data.bestStreak.toDouble(),
                label: 'Longest streak',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 7 / 30 / 90 day window selector used by the completion chart.
class _WindowSelector extends StatelessWidget {
  const _WindowSelector({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in const [7, 30, 90])
            InkWell(
              onTap: () => onChanged(d),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: days == d ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${d}d',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: days == d ? scheme.onPrimary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.data, required this.windowDays});

  final AnalyticsData data;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Real counts carried by the provider — the completion bars were fed an
    // empty map before, rendering every bar at 0%.
    final stats = data.completionForWindow(data.habits, data.counts, windowDays);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Last $windowDays days',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _PercentPill(
                  percent: windowDays == 7
                      ? data.weekCompletion
                      : data.monthCompletion,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (stats.isEmpty)
              Text(
                'No habits yet — completion appears once you add one.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              AnimatedBarChart(
                items: [
                  for (final s in stats.take(8))
                    BarItem(
                      label: s.habit.name,
                      value: s.rate,
                      color: Color(s.habit.color),
                      subtitle: '${s.doneDays}/${s.totalDays} days',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = (percent * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$p%',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
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
    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Journal entries with moods will appear here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final total = stats.fold<int>(0, (sum, s) => sum + s.count);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mood distribution',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$total entries',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: DonutChart(
                    segments: [
                      for (final s in stats)
                        DonutSegment(
                          value: s.count.toDouble(),
                          color: s.mood.color,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in stats.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: s.mood.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${s.mood.emoji} ${s.mood.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '${s.count}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      if (stats.length > 6)
                        Text(
                          '+${stats.length - 6} more',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalFrequencyCard extends StatelessWidget {
  const _JournalFrequencyCard({required this.frequency});

  final List<JournalFrequency> frequency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final months = frequency.takeLast(6);
    final maxCount = months.fold<int>(1, (m, f) => f.count > m ? f.count : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entries per month',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (months.isEmpty)
              Text(
                'No entries yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final f in months)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Text(
                              '${f.count}',
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
                              height: 60 * (f.count / maxCount),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.35),
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
                              _monthLabel(f.month),
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
      ),
    );
  }

  static String _monthLabel(DateTime m) => DateFormatShort.month(m);
}

class _BestCard extends StatelessWidget {
  const _BestCard({required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bestDay = data.bestDay;
    final bestMonth = data.bestMonth;
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.star, color: const Color(0xFFF59E0B), size: 20),
                  const SizedBox(height: 8),
                  Text(
                    'Best day',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bestDay == null ? '—' : '${AppDate.formatShort(bestDay)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (bestDay != null)
                    Text(
                      '${data.bestDayCount} habits done',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.emoji_events,
                      color: const Color(0xFF10B981), size: 20),
                  const SizedBox(height: 8),
                  Text(
                    'Best month',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bestMonth == null ? '—' : AppDate.monthYear(bestMonth),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (bestMonth != null)
                    Text(
                      '${(data.bestMonthRate * 100).round()}% completion',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final habitStats = data.habitCategoryStats;
    final noteStats = data.noteCategoryStats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (habitStats.isNotEmpty) ...[
              Text(
                'Habits by category',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final s in habitStats) _CategoryRow(stat: s, showRate: true),
              if (noteStats.isNotEmpty) const SizedBox(height: 16),
            ],
            if (noteStats.isNotEmpty) ...[
              Text(
                'Notes by category',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final s in noteStats) _CategoryRow(stat: s, showRate: false),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.stat, required this.showRate});

  final CategoryStat stat;
  final bool showRate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = stat.color == null
        ? scheme.onSurfaceVariant
        : Color(stat.color!);
    final rate = stat.rate ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                showRate
                    ? '${stat.count} habits · ${(rate * 100).round()}%'
                    : '${stat.count} notes',
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
              value: showRate ? rate.clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              color: color,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _ActivityRow(entry: entries[i]),
            if (i != entries.length - 1)
              Divider(height: 1, indent: 64, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = entry.color == null
        ? scheme.onSurfaceVariant
        : Color(entry.color!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(entry.icon, style: const TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  entry.subtitle,
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
          Text(
            _timeAgo(entry.timestamp),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(int ts) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return AppDate.formatShort(DateTime.fromMillisecondsSinceEpoch(ts));
  }
}

/// Fade + slide wrapper whose animation window is staggered by [index].
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.05).clamp(0.0, 0.55).toDouble();
    final end = (start + 0.45).clamp(0.55, 1.0).toDouble();
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable animated chart widgets
// ---------------------------------------------------------------------------

/// Animated donut chart built from segments.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.segments});

  final List<DonutSegment> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant, width: 8),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        painter: _DonutPainter(
          segments: segments,
          total: total,
          progress: t,
          scheme: scheme,
        ),
        child: const SizedBox(width: 120, height: 120),
      ),
    );
  }
}

class DonutSegment {
  const DonutSegment({required this.value, required this.color});

  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.scheme,
  });

  final List<DonutSegment> segments;
  final double total;
  final double progress;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;
    final stroke = radius * 0.42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = scheme.surfaceContainerHigh;
    canvas.drawCircle(center, radius - stroke / 2, bgPaint);

    if (total <= 0) return;
    const start = -math.pi / 2;
    var angle = start;
    for (final s in segments) {
      final sweep = (s.value / total) * 2 * math.pi * progress;
      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        angle,
        sweep,
        false,
        paint,
      );
      angle += (s.value / total) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total ||
      old.progress != progress ||
      old.segments != segments;
}

/// Animated horizontal bar list (per-habit completion).
class AnimatedBarChart extends StatelessWidget {
  const AnimatedBarChart({super.key, required this.items});

  final List<BarItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i != 0) const SizedBox(height: 10),
          _BarRow(item: items[i]),
        ],
      ],
    );
  }
}

class BarItem {
  const BarItem({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final String label;
  final double value; // 0..1
  final Color color;
  final String? subtitle;
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.item});

  final BarItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            const SizedBox(width: 8),
            Text(
              '${(item.value * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: item.value),
            duration: Duration(milliseconds: 500 + item.label.length * 10),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v.clamp(0.0, 1.0),
              minHeight: 8,
              color: item.color,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ),
      ],
    );
  }
}

/// Minimal month label helper (kept local to avoid extra intl imports here).
class DateFormatShort {
  DateFormatShort._();

  static String month(DateTime m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m.month - 1];
  }
}

/// `takeLast` on a list (used for the last 6 frequency months).
extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
