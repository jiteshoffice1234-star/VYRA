import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/habits/habit_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/list_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/theme/vyra_style.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/month_calendar.dart';
import '../../domain/models/habit.dart';
import '../../domain/services/habit_stats.dart';
import '../../widgets/habit_check.dart';
import '../../widgets/habit_week_strip.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(habitsProvider);
    final habit = list.valueOrNull?.firstWhereOrNull((h) => h.id == widget.id);
    final style = VyraStyle.of(context);

    if (list.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: Icons.search_off,
          title: 'Habit not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    }

    final counts = ref.watch(habitCountsProvider(widget.id));

    final color = Color(habit.color);
    final currentStreak = HabitStats.currentStreak(habit, counts);
    final longestStreak = HabitStats.longestStreak(habit, counts);
    final weekCompletion = HabitStats.weekCompletion(habit, counts);
    final monthCompletion = HabitStats.monthCompletion(habit, counts);
    final totalDone = HabitStats.daysDone(
      habit,
      counts,
      AppDate.startOfDay(DateTime.fromMillisecondsSinceEpoch(habit.createdAt)),
      DateTime.now(),
    );
    final todayCount = counts[AppDate.dayKey(DateTime.now())] ?? 0;

    final monthDoneDays = <String>{};
    final daysInMonth = AppDate.daysInMonth(_month);
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_month.year, _month.month, d);
      if (HabitStats.isDoneOn(habit, counts, day)) {
        monthDoneDays.add(AppDate.dayKey(day));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'archive') _toggleArchive(context);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  habit.archived ? 'Restore habit' : 'Archive habit',
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => context.push('/habit/editor?id=${habit.id}'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(style.radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.55)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    AppConstants.habitIcons[
                        habit.iconIndex % AppConstants.habitIcons.length],
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        habit.categoryName ??
                            (habit.type == HabitType.good
                                ? 'Good habit'
                                : 'Bad habit'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                HabitCheck(
                  habit: habit,
                  size: 38,
                  onChanged: () =>
                      ref.read(habitsProvider.notifier).toggleToday(habit),
                ),
              ],
            ),
          ),
          if (habit.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              habit.description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 20),

          // Today's progress
          if (habit.type == HabitType.good) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.today, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Today: $todayCount / ${habit.targetPerDay}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: todayCount > 0
                          ? () => ref
                              .read(habitsProvider.notifier)
                              .adjustCount(habit, -1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => ref
                          .read(habitsProvider.notifier)
                          .adjustCount(habit, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Stats
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department,
                  value: '$currentStreak',
                  label: 'Current streak',
                  color: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.emoji_events,
                  value: '$longestStreak',
                  label: 'Longest streak',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.percent,
                  value: '${(monthCompletion * 100).round()}%',
                  label: 'This month',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.check_circle,
                  value: '$totalDone',
                  label: 'Total days',
                  color: const Color(0xFF6C5CE7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Weekly view
          AppSectionHeader(title: 'This week'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: HabitWeekStrip(habit: habit, counts: counts),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${(weekCompletion * 100).round()}% completed this week',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 20),

          // Monthly calendar history
          AppSectionHeader(title: 'History'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MonthCalendar(
                month: _month,
                secondaryDays: monthDoneDays,
                onMonthChanged: (m) => setState(() => _month = m),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Archives (hides) or restores the habit. History is always preserved.
  Future<void> _toggleArchive(BuildContext context) async {
    final wasArchived = habit.archived;
    try {
      await ref
          .read(habitsProvider.notifier)
          .setArchived(habit, !wasArchived);
    } catch (e, st) {
      AppLogger.error('Failed to update habit archive state', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not update the habit.');
      }
      return;
    }
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      wasArchived ? 'Habit restored.' : 'Habit archived.',
    );
    // Archiving hides the habit from the active list, so leave the detail.
    if (!wasArchived) context.pop();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Delete habit?',
      message: 'This habit and its entire history will be removed.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(habitsProvider.notifier).delete(widget.id);
    } catch (e, st) {
      AppLogger.error('Failed to delete habit', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not delete the habit.');
      }
      return;
    }
    if (context.mounted) context.pop();
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.radius),
        border: style.border ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
