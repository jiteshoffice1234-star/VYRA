import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/habits/habit_providers.dart';
import '../../../application/providers/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/list_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/month_calendar.dart';
import '../../../domain/models/habit.dart';
import '../../../domain/services/habit_stats.dart';
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

  /// True while a reminder toggle / time change is being saved, so rapid
  /// double-taps can't race two saves.
  bool _reminderBusy = false;

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

          // Reminder: quick enable/disable + scheduled time.
          AppSectionHeader(title: 'Reminder'),
          const SizedBox(height: 12),
          _ReminderCard(
            habit: habit,
            busy: _reminderBusy,
            onToggle: _toggleReminder,
            onPickTime: _pickReminderTime,
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

          // Monthly calendar history — tappable to log past days.
          AppSectionHeader(title: 'History'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  MonthCalendar(
                    month: _month,
                    secondaryDays: monthDoneDays,
                    onMonthChanged: (m) => setState(() => _month = m),
                    onSelectDay: _toggleDay,
                    isDayEnabled: (d) => !d.isAfter(DateTime.now()),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tap a day to log or undo it',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logs or undoes a past day from the history calendar. Reuses the
  /// notifier's setCount pipeline; future days are rejected by the calendar.
  Future<void> _toggleDay(DateTime day) async {
    final habit = (ref.read(habitsProvider).valueOrNull ?? const <Habit>[])
        .firstWhereOrNull((h) => h.id == widget.id);
    if (habit == null) return;
    try {
      await ref.read(habitsProvider.notifier).toggleDay(habit, day);
    } catch (e, st) {
      AppLogger.error('Failed to update habit history', e, st);
      if (mounted) {
        showAppSnackBar(context, 'Could not update that day.');
      }
    }
  }

  /// Enables/disables the daily reminder by saving the habit (the notifier
  /// schedules or cancels the notification to match).
  Future<void> _toggleReminder(bool enabled) async {
    if (_reminderBusy) return;
    final habit = (ref.read(habitsProvider).valueOrNull ?? const <Habit>[])
        .firstWhereOrNull((h) => h.id == widget.id);
    if (habit == null) return;
    setState(() => _reminderBusy = true);
    try {
      final updated = habit.copyWith(
        reminderEnabled: enabled,
        reminderTime: enabled
            ? (habit.reminderTime ?? _defaultReminderTime())
            : null,
      );
      await ref.read(habitsProvider.notifier).save(updated);
      if (enabled) _requestReminderPermission();
    } catch (e, st) {
      AppLogger.error('Failed to update habit reminder', e, st);
      if (mounted) {
        showAppSnackBar(context, 'Could not update the reminder.');
      }
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  /// Changes the scheduled reminder time via the system time picker.
  Future<void> _pickReminderTime() async {
    final habit = (ref.read(habitsProvider).valueOrNull ?? const <Habit>[])
        .firstWhereOrNull((h) => h.id == widget.id);
    if (habit == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseReminderTime(habit.reminderTime) ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    final current = (ref.read(habitsProvider).valueOrNull ?? const <Habit>[])
        .firstWhereOrNull((h) => h.id == widget.id);
    if (current == null) return;
    final time =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _reminderBusy = true);
    try {
      await ref
          .read(habitsProvider.notifier)
          .save(current.copyWith(reminderTime: time));
    } catch (e, st) {
      AppLogger.error('Failed to update reminder time', e, st);
      if (mounted) {
        showAppSnackBar(context, 'Could not update the reminder time.');
      }
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  String _defaultReminderTime() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  /// Parses an "HH:mm" string into a [TimeOfDay], null when malformed.
  TimeOfDay? _parseReminderTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  /// Android 13+ shows a system permission prompt; if denied, point the user
  /// at system settings. The reminder is still saved either way.
  Future<void> _requestReminderPermission() async {
    try {
      final granted =
          await ref.read(reminderSchedulerProvider).requestPermission();
      if (!mounted || granted) return;
      showAppSnackBar(
        context,
        'Notifications are blocked — enable them in system settings to get reminders.',
      );
    } catch (e, st) {
      AppLogger.error('Failed to request notification permission', e, st);
    }
  }

  /// Archives (hides) or restores the habit. History is always preserved.
  Future<void> _toggleArchive(BuildContext context) async {
    final habit = (ref.read(habitsProvider).valueOrNull ?? const <Habit>[])
        .firstWhereOrNull((h) => h.id == widget.id);
    if (habit == null) return;
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

/// Quick reminder enable/disable + scheduled time, mirroring the editor's
/// reminder settings but without leaving the detail screen.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.habit,
    required this.busy,
    required this.onToggle,
    required this.onPickTime,
  });

  final Habit habit;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final time = _displayTime(habit.reminderTime);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: habit.reminderEnabled,
            onChanged: busy ? null : (v) => onToggle(v),
            title: const Text('Enable reminder'),
            subtitle: Text(
              habit.reminderEnabled
                  ? 'Get a daily nudge at your set time'
                  : 'Get a daily nudge at your chosen time',
            ),
          ),
          if (habit.reminderEnabled) ...[
            Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(
                time == null ? 'Set time' : 'Daily at $time',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : onPickTime,
            ),
          ],
        ],
      ),
    );
  }

  static String? _displayTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return AppDate.formatTime(DateTime(2026, 1, 1, h, m));
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
        border: style.boxBorder ??
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
