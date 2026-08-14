import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/dashboard/dashboard_provider.dart';
import '../../../application/habits/habit_providers.dart';
import '../../../application/journal/journal_providers.dart';
import '../../../application/notes/note_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/month_calendar.dart';
import '../../../core/widgets/quote_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../domain/models/habit.dart';
import '../../../domain/models/journal_entry.dart';
import '../../../domain/models/note.dart';
import '../../../domain/services/habit_stats.dart';
import '../../widgets/habit_check.dart';

/// Home dashboard organised into four sub-tabs — Overview, Today, Activity,
/// Insights — so the first screen stays scannable without endless scrolling.
/// The greeting, date, search and quick actions stay fixed on top; each tab
/// preserves its state (scroll position, calendar month) via keep-alive.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const _HomeLoading(),
      error: (error, _) => _HomeError(
        message: '$error',
        onRetry: () => ref.invalidate(dashboardProvider),
      ),
      data: (data) => _HomeContent(data: data),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                'V',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: 'Could not load your dashboard',
      subtitle: message,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

/// Fixed header + quick actions + sub-tab bar + a paged tab body. The header
/// area never scrolls away, so the essentials stay one tap away at all times.
class _HomeContent extends ConsumerStatefulWidget {
  const _HomeContent({required this.data});

  final DashboardData data;

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final PageController _pageController = PageController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return SafeArea(
      child: Column(
        children: [
          _Entrance(
            controller: _entrance,
            index: 0,
            child: const _GreetingHeader(),
          ),
          const SizedBox(height: 12),
          _Entrance(controller: _entrance, index: 1, child: const _QuickAddRow()),
          const SizedBox(height: 14),
          _HomeTabs(index: _tab, onChanged: _selectTab),
          const SizedBox(height: 6),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _tab = i),
              children: [
                _OverviewTab(data: data),
                _TodayTab(data: data),
                _ActivityTab(data: data),
                _InsightsTab(data: data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented sub-tab bar: Overview · Today · Activity · Insights.
class _HomeTabs extends StatelessWidget {
  const _HomeTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    const labels = ['Overview', 'Today', 'Activity', 'Insights'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(style.radius),
          border: style.boxBorder ??
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(style.radius - 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: i == index ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(style.radius - 4),
                    ),
                    child: Text(
                      style.uppercaseLabels ? labels[i].toUpperCase() : labels[i],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: i == index
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppConstants.pagePadding, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppDate.greeting(DateTime.now())} 👋',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  AppDate.formatFull(DateTime.now()),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
      child: Row(
        children: [
          Expanded(
            child: _QuickAddButton(
              icon: Icons.menu_book,
              color: const Color(0xFF6C5CE7),
              label: 'Journal',
              onTap: () => context.push('/journal/editor'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAddButton(
              icon: Icons.repeat,
              color: const Color(0xFF10B981),
              label: 'Habit',
              onTap: () => context.push('/habit/editor'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAddButton(
              icon: Icons.sticky_note_2,
              color: const Color(0xFFF59E0B),
              label: 'Note',
              onTap: () => context.push('/note/editor'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAddButton(
              icon: Icons.search,
              color: const Color(0xFF0EA5E9),
              label: 'Search',
              onTap: () => context.push('/search'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(style.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(style.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(style.radius),
            border: style.boxBorder ??
                Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
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
    final start = (index * 0.12).clamp(0.0, 0.4).toDouble();
    final end = (start + 0.4).clamp(0.4, 1.0).toDouble();
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

// --------------------------------------------------------------------------
// Overview tab: progress ring, streak, timeline/analytics links, calendar,
// quote — the essentials in one compact view.
// --------------------------------------------------------------------------
class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.data});

  final DashboardData data;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = widget.data;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        4,
        AppConstants.pagePadding,
        24,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ProgressRingCard(
                done: data.todayDone,
                total: data.todayTotal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StreakCard(
                streak: data.bestCurrentStreak,
                longest: data.bestLongestStreak,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HistoryEntryCard(
          onTimeline: () => context.go('/timeline'),
          onAnalytics: () => context.push('/analytics'),
        ),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Calendar'),
        const SizedBox(height: 10),
        _CalendarPreviewCard(
          month: DateTime.now(),
          journalDays: data.journalDayKeys,
          habitDays: data.habitDayKeys,
          onSelectDay: (day) {
            ref.read(journalDateProvider.notifier).state = day;
            context.go('/journal');
          },
        ),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Quote of the day'),
        const SizedBox(height: 10),
        QuoteCard(quote: quoteOfTheDay()),
      ],
    );
  }
}

/// Today's habit completion as an animated progress ring.
class _ProgressRingCard extends StatelessWidget {
  const _ProgressRingCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final pct = total == 0 ? 0.0 : done / total;

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
              Icon(Icons.today, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Daily progress',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$done/$total',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'done',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Current + longest streak in one compact card.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.longest});

  final int streak;
  final int longest;

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
              Icon(Icons.local_fire_department,
                  size: 16, color: const Color(0xFFF97316)),
              const SizedBox(width: 6),
              Text(
                'Streak',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$streak',
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            '${TextUtil.plural(streak, 'day')} in a row',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Best $longest',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFF59E0B),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact card linking to the timeline and analytics screens.
class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({
    required this.onTimeline,
    required this.onAnalytics,
  });

  final VoidCallback onTimeline;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _HistoryRow(
            icon: Icons.timeline,
            color: scheme.primary,
            title: 'Your timeline',
            subtitle: 'Day by day history',
            onTap: onTimeline,
          ),
          Divider(height: 1, indent: 56, endIndent: 12),
          _HistoryRow(
            icon: Icons.insights,
            color: const Color(0xFF8B5CF6),
            title: 'Analytics',
            subtitle: 'Habits, moods & trends',
            onTap: onAnalytics,
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(style.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CalendarPreviewCard extends StatelessWidget {
  const _CalendarPreviewCard({
    required this.month,
    required this.journalDays,
    required this.habitDays,
    this.onSelectDay,
  });

  final DateTime month;
  final Set<String> journalDays;
  final Set<String> habitDays;
  final ValueChanged<DateTime>? onSelectDay;

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
                  AppDate.monthYear(month),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(Icons.calendar_month, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          MonthCalendar(
            month: month,
            primaryDays: journalDays,
            secondaryDays: habitDays,
            navigable: false,
            onSelectDay: onSelectDay,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(scheme.primary),
              const SizedBox(width: 6),
              Text('Journal', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 16),
              _legendDot(scheme.tertiary),
              const SizedBox(width: 6),
              Text('Habits', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// --------------------------------------------------------------------------
// Today tab: today's journal, habits, pending items, notes and quick adds.
// No historical information here — strictly today.
// --------------------------------------------------------------------------
class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab({required this.data});

  final DashboardData data;

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = widget.data;
    final today = AppDate.today();
    final notes = ref.watch(notesProvider).valueOrNull ?? const <Note>[];
    final todayNotes = notes
        .where(
          (n) => AppDate.isSameDay(
            DateTime.fromMillisecondsSinceEpoch(n.updatedAt),
            today,
          ),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final counts = ref.watch(habitCountsMapProvider).valueOrNull ?? const {};
    final pending = data.todayHabits
        .where(
          (h) =>
              !HabitStats.isDoneOn(h, counts[h.id] ?? const {}, DateTime.now()),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        4,
        AppConstants.pagePadding,
        24,
      ),
      children: [
        const AppSectionHeader(title: 'Today’s journal'),
        const SizedBox(height: 10),
        _TodayJournalCard(
          entry: data.todayJournal,
          onWrite: () => context.push('/journal/editor'),
          onOpen: (e) {
            if (e.id != null) context.push('/journal/detail/${e.id}');
          },
        ),
        const SizedBox(height: 20),
        AppSectionHeader(
          title: 'Today’s habits',
          trailing: Text(
            '${data.todayDone}/${data.todayTotal}',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        _TodayHabitsCard(habits: data.todayHabits),
        const SizedBox(height: 20),
        AppSectionHeader(
          title: 'Pending',
          trailing: Text(
            '${pending.length} left',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(height: 10),
        _PendingCard(habits: pending),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Today’s notes'),
        const SizedBox(height: 10),
        _TodayNotesCard(notes: todayNotes),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Quick add'),
        const SizedBox(height: 10),
        const _TodayQuickAddCard(),
      ],
    );
  }
}

/// Status card for today's journal: prompts to write when missing, shows the
/// entry when present.
class _TodayJournalCard extends StatelessWidget {
  const _TodayJournalCard({
    required this.entry,
    required this.onWrite,
    required this.onOpen,
  });

  final JournalEntry? entry;
  final VoidCallback onWrite;
  final ValueChanged<JournalEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final e = entry;

    if (e == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(style.radius),
          border: style.boxBorder ??
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(style.radius),
              ),
              child: Icon(Icons.edit_note, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No entry yet today',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reflect on your day in a minute.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onWrite,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Write'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: () => onOpen(e),
        borderRadius: BorderRadius.circular(style.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(style.radius),
                ),
                child: Center(
                  child: Text(e.mood.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: const Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'Journaled today',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayHabitsCard extends ConsumerWidget {
  const _TodayHabitsCard({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);

    if (habits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(style.radius),
          border: style.boxBorder ??
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.repeat, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No habits yet. Tap + to create your first one.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < habits.length; i++) ...[
            _HabitRow(habit: habits[i]),
            if (i != habits.length - 1)
              Divider(height: 1, indent: 68, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final color = Color(habit.color);

    return InkWell(
      onTap: () => context.push('/habit/detail/${habit.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(style.radius),
              ),
              child: Icon(
                AppConstants.habitIcons[
                    habit.iconIndex % AppConstants.habitIcons.length],
                size: 18,
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
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (habit.categoryName != null)
                    Text(
                      habit.categoryName!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            HabitCheck(
              habit: habit,
              onChanged: () =>
                  ref.read(habitsProvider.notifier).toggleToday(habit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact list of habits still left for today.
class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);

    if (habits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(style.radius),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.task_alt, color: const Color(0xFF10B981)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All caught up — nothing pending today!',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < habits.length; i++) ...[
            _PendingRow(habit: habits[i]),
            if (i != habits.length - 1)
              Divider(height: 1, indent: 68, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = VyraStyle.of(context);
    final color = Color(habit.color);

    return InkWell(
      onTap: () => context.push('/habit/detail/${habit.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(style.radius),
              ),
              child: Icon(
                AppConstants.habitIcons[
                    habit.iconIndex % AppConstants.habitIcons.length],
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            HabitCheck(
              habit: habit,
              onChanged: () =>
                  ref.read(habitsProvider.notifier).toggleToday(habit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notes touched today, newest first.
class _TodayNotesCard extends StatelessWidget {
  const _TodayNotesCard({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);

    if (notes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(style.radius),
          border: style.boxBorder ??
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No notes updated today.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            _NoteRow(note: notes[i]),
            if (i != notes.length - 1)
              Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(note.color);

    return InkWell(
      onTap: () => context.push('/note/detail/${note.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                note.type == NoteType.text
                    ? Icons.sticky_note_2
                    : Icons.checklist,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              note.type == NoteType.text
                  ? TextUtil.excerpt(note.content, maxChars: 24)
                  : '${note.checkedCount}/${note.items.length}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline quick-add buttons so today's flow never needs the FAB.
class _TodayQuickAddCard extends StatelessWidget {
  const _TodayQuickAddCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickChip(
              icon: Icons.menu_book,
              color: const Color(0xFF6C5CE7),
              label: 'Journal',
              onTap: () => context.push('/journal/editor'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickChip(
              icon: Icons.repeat,
              color: const Color(0xFF10B981),
              label: 'Habit',
              onTap: () => context.push('/habit/editor'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickChip(
              icon: Icons.sticky_note_2,
              color: const Color(0xFFF59E0B),
              label: 'Note',
              onTap: () => context.push('/note/editor'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Activity tab: recent journals, recently completed habits, recent notes and
// the most recently updated items — each row navigates to the item.
// --------------------------------------------------------------------------
class _ActivityTab extends ConsumerStatefulWidget {
  const _ActivityTab({required this.data});

  final DashboardData data;

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Recently completed habits, newest first (most recent done day per habit).
  List<(Habit, String)> _recentlyDone(
    List<Habit> habits,
    Map<int, Map<String, int>> counts,
  ) {
    final today = AppDate.today();
    final out = <(Habit, String)>[];
    for (final habit in habits) {
      final c = counts[habit.id] ?? const <String, int>{};
      // Walk back up to 7 days to find the habit's most recent done day.
      for (var i = 0; i < 7; i++) {
        final day = AppDate.addDays(today, -i);
        if (HabitStats.isDoneOn(habit, c, day)) {
          out.add((habit, AppDate.dayKey(day)));
          break;
        }
      }
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final journals = ref.watch(journalListProvider).valueOrNull ?? const [];
    final notes = ref.watch(notesProvider).valueOrNull ?? const [];
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final counts = ref.watch(habitCountsMapProvider).valueOrNull ?? const {};

    final recentJournals = journals.take(3).toList();
    final recentNotes = [...notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final doneHabits = _recentlyDone(habits, counts).take(4).toList();

    // Last updated: journals + notes merged by timestamp, newest first.
    final updated = <({int ts, String title, String kind, int id})>[
      for (final j in journals)
        (ts: j.updatedAt, title: j.title, kind: 'journal', id: j.id ?? -1),
      for (final n in notes)
        (ts: n.updatedAt, title: n.title, kind: 'note', id: n.id ?? -1),
    ]..sort((a, b) => b.ts.compareTo(a.ts));
    final lastUpdated = updated.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        4,
        AppConstants.pagePadding,
        24,
      ),
      children: [
        const AppSectionHeader(title: 'Recent journal'),
        const SizedBox(height: 10),
        _RecentJournalsCard(entries: recentJournals),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Completed habits'),
        const SizedBox(height: 10),
        _RecentHabitsCard(done: doneHabits),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Recent notes'),
        const SizedBox(height: 10),
        _RecentNotesCard(notes: recentNotes.take(3).toList()),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Last updated'),
        const SizedBox(height: 10),
        _LastUpdatedCard(items: lastUpdated),
      ],
    );
  }
}

class _RecentJournalsCard extends StatelessWidget {
  const _RecentJournalsCard({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    if (entries.isEmpty) {
      return _InlineHint(
        icon: Icons.menu_book,
        text: 'No journal entries yet.',
        actionLabel: 'Write one',
        onAction: () => context.push('/journal/editor'),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _JournalRow(entry: entries[i]),
            if (i != entries.length - 1)
              Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return InkWell(
      onTap: () {
        if (entry.id != null) context.push('/journal/detail/${entry.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(style.radius),
              ),
              child: Center(
                child: Text(entry.mood.emoji, style: const TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    AppDate.formatMedium(entry.entryDate),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RecentHabitsCard extends StatelessWidget {
  const _RecentHabitsCard({required this.done});

  final List<(Habit, String)> done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    if (done.isEmpty) {
      return _InlineHint(
        icon: Icons.repeat,
        text: 'No habits completed recently.',
        actionLabel: 'Add a habit',
        onAction: () => context.push('/habit/editor'),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < done.length; i++) ...[
            _DoneHabitRow(habit: done[i].$1, dayKey: done[i].$2),
            if (i != done.length - 1)
              Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _DoneHabitRow extends StatelessWidget {
  const _DoneHabitRow({required this.habit, required this.dayKey});

  final Habit habit;
  final String dayKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final color = Color(habit.color);
    final day = AppDate.parseDayKey(dayKey);
    final label = AppDate.isToday(day)
        ? 'Today'
        : AppDate.isSameDay(day, AppDate.addDays(DateTime.now(), -1))
            ? 'Yesterday'
            : AppDate.formatMedium(day);

    return InkWell(
      onTap: () => context.push('/habit/detail/${habit.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(style.radius),
              ),
              child: Icon(
                AppConstants.habitIcons[
                    habit.iconIndex % AppConstants.habitIcons.length],
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: const Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  label,
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
    );
  }
}

class _RecentNotesCard extends StatelessWidget {
  const _RecentNotesCard({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    if (notes.isEmpty) {
      return _InlineHint(
        icon: Icons.sticky_note_2,
        text: 'No notes yet.',
        actionLabel: 'New note',
        onAction: () => context.push('/note/editor'),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            _NoteRow(note: notes[i]),
            if (i != notes.length - 1)
              Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _LastUpdatedCard extends StatelessWidget {
  const _LastUpdatedCard({required this.items});

  final List<({int ts, String title, String kind, int id})> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    if (items.isEmpty) {
      return _InlineHint(
        icon: Icons.schedule,
        text: 'Nothing updated yet.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _UpdatedRow(item: items[i]),
            if (i != items.length - 1)
              Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _UpdatedRow extends StatelessWidget {
  const _UpdatedRow({required this.item});

  final ({int ts, String title, String kind, int id}) item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isJournal = item.kind == 'journal';
    final color = isJournal ? const Color(0xFF6C5CE7) : const Color(0xFFF59E0B);

    return InkWell(
      onTap: () {
        if (item.id <= 0) return;
        if (isJournal) {
          context.push('/journal/detail/${item.id}');
        } else {
          context.push('/note/detail/${item.id}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isJournal ? Icons.menu_book : Icons.sticky_note_2,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              _timeAgo(item.ts),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(int ts) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return AppDate.formatShort(DateTime.fromMillisecondsSinceEpoch(ts));
  }
}

/// Small inline empty-state hint with an optional action.
class _InlineHint extends StatelessWidget {
  const _InlineHint({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Insights tab: statistics and lightweight charts only.
// --------------------------------------------------------------------------
class _InsightsTab extends ConsumerStatefulWidget {
  const _InsightsTab({required this.data});

  final DashboardData data;

  @override
  ConsumerState<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends ConsumerState<_InsightsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = widget.data;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        4,
        AppConstants.pagePadding,
        24,
      ),
      children: [
        _WeekReviewEntry(data: data),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.menu_book,
                color: const Color(0xFF6C5CE7),
                value: data.journalCount.toDouble(),
                label: 'Journal entries',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.sticky_note_2,
                color: const Color(0xFFF59E0B),
                value: data.noteCount.toDouble(),
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
                icon: Icons.local_fire_department,
                color: const Color(0xFFF97316),
                value: data.bestCurrentStreak.toDouble(),
                label: 'Current streak',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: Icons.emoji_events,
                color: const Color(0xFFF59E0B),
                value: data.bestLongestStreak.toDouble(),
                label: 'Longest streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Progress'),
        const SizedBox(height: 10),
        _ProgressCard(data: data),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Last 7 days'),
        const SizedBox(height: 10),
        _WeekCard(bars: data.weekBars),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Habit completion'),
        const SizedBox(height: 10),
        _CompletionCard(data: data),
      ],
    );
  }
}

/// Entry card for the "This Week" review screen, shown at the top of the
/// Insights tab.
class _WeekReviewEntry extends StatelessWidget {
  const _WeekReviewEntry({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final pct = (data.weeklyProgress * 100).round();
    return Card(
      child: InkWell(
        onTap: () => context.push('/week-review'),
        borderRadius: BorderRadius.circular(style.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_awesome, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.weeklyProgress > 0
                          ? '$pct% of habits done · your week in review'
                          : 'Your week in review — habits, moods & streaks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.data});

  final DashboardData data;

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
        children: [
          _ProgressRow(
            label: 'Weekly progress',
            value: data.weeklyProgress,
            color: const Color(0xFF6C5CE7),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'Monthly progress',
            value: data.monthlyProgress,
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: scheme.surfaceContainerHigh,
          ),
        ),
      ],
    );
  }
}

/// Compact 7-day completion bar chart.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.bars});

  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final today = AppDate.today();
    final start = AppDate.addDays(today, -6);

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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: 40 * bars[i].clamp(0.0, 1.0).toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == 6
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppDate.weekdayLetter(AppDate.addDays(start, i)),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Per-habit completion this week, compact.
class _CompletionCard extends ConsumerWidget {
  const _CompletionCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final counts = ref.watch(habitCountsMapProvider).valueOrNull ?? const {};
    final today = AppDate.today();
    final weekStart = AppDate.addDays(today, -6);

    final rows = <({Habit habit, double rate})>[
      for (final habit in data.todayHabits)
        (
          habit: habit,
          rate: HabitStats.completion(
            habit,
            counts[habit.id] ?? const <String, int>{},
            weekStart,
            today,
          ),
        ),
    ]..sort((a, b) => b.rate.compareTo(a.rate));

    if (rows.isEmpty) {
      return _InlineHint(
        icon: Icons.percent,
        text: 'No habits yet — completion appears once you add one.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.boxBorder ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _CompletionRow(habit: rows[i].habit, rate: rows[i].rate),
            if (i != rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CompletionRow extends StatelessWidget {
  const _CompletionRow({required this.habit, required this.rate});

  final Habit habit;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(habit.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${(rate * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: rate.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: scheme.surfaceContainerHigh,
          ),
        ),
      ],
    );
  }
}

