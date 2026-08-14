import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

/// Interactive month calendar with optional markers for journal / habit days.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    this.primaryDays = const {},
    this.secondaryDays = const {},
    this.selectedDay,
    this.onSelectDay,
    this.onMonthChanged,
    this.navigable = true,
    this.isDayEnabled,
  });

  final DateTime month;
  final Set<String> primaryDays;
  final Set<String> secondaryDays;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onSelectDay;
  final ValueChanged<DateTime>? onMonthChanged;
  final bool navigable;

  /// Optional per-day gate for tap targets (e.g. never allow future days).
  /// When it returns false the cell is dimmed and not tappable. Null means
  /// every day is tappable (previous behaviour).
  final bool Function(DateTime day)? isDayEnabled;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = AppDate.startOfDay(widget.month);
  }

  @override
  void didUpdateWidget(covariant MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!AppDate.isSameMonth(oldWidget.month, widget.month)) {
      _month = AppDate.startOfDay(widget.month);
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
    widget.onMonthChanged?.call(_month);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final offset = firstDay.weekday - 1; // week starts Monday
    final daysInMonth = AppDate.daysInMonth(_month);
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.navigable ? () => _shiftMonth(-1) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Center(
                child: Text(
                  AppDate.monthYear(_month),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              onPressed: widget.navigable ? () => _shiftMonth(1) : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final label in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                _buildCell(row * 7 + col, offset, daysInMonth, scheme),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int cellIndex, int offset, int daysInMonth, ColorScheme scheme) {
    final dayNumber = cellIndex - offset + 1;
    final isEmpty = dayNumber < 1 || dayNumber > daysInMonth;

    if (isEmpty) return const Expanded(child: SizedBox());

    final day = DateTime(_month.year, _month.month, dayNumber);
    final dayKey = AppDate.dayKey(day);
    final isSelected = widget.selectedDay != null && AppDate.isSameDay(day, widget.selectedDay!);
    final isToday = AppDate.isToday(day);
    final enabled = widget.isDayEnabled?.call(day) ?? true;
    final hasPrimary = widget.primaryDays.contains(dayKey);
    final hasSecondary = widget.secondaryDays.contains(dayKey);

    return Expanded(
      child: GestureDetector(
        onTap: enabled && widget.onSelectDay != null
            ? () => widget.onSelectDay!(day)
            : null,
        child: Container(
          height: 44,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : null,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(color: scheme.primary, width: 1.4)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? scheme.onPrimary
                          : enabled
                              ? scheme.onSurface
                              : scheme.outlineVariant,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(hasPrimary, scheme.primary),
                  const SizedBox(width: 2),
                  _dot(hasSecondary, scheme.tertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(bool visible, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: visible ? color : Colors.transparent,
        shape: BoxShape.circle,
      ),
    );
  }
}
