import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/categories/category_providers.dart';
import '../../../application/habits/habit_providers.dart';
import '../../../application/providers/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/utils/list_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/category_dialog.dart';
import '../../../core/widgets/color_dot.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/habit.dart';

class HabitEditorScreen extends ConsumerStatefulWidget {
  const HabitEditorScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends ConsumerState<HabitEditorScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  HabitType _type = HabitType.good;
  int _colorIndex = 0;
  int _iconIndex = 0;
  int? _categoryId;
  int _target = 1;
  bool _reminderEnabled = false;
  String? _reminderTime;
  int? _originalCreatedAt;
  bool _saving = false;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _loadExisting();
  }

  /// Loads the habit being edited, falling back to the repository so deep
  /// links opened before the list finishes loading still work.
  Future<void> _loadExisting() async {
    var habit = (ref.read(habitsProvider).valueOrNull ?? const <Habit>[])
        .firstWhereOrNull((h) => h.id == widget.id);
    if (habit == null) {
      try {
        final repo = await ref.read(habitRepositoryProvider.future);
        habit = await repo.getById(widget.id!);
      } catch (e, st) {
        AppLogger.error('Failed to load habit for editing', e, st);
      }
    }
    if (!mounted) return;
    if (habit == null) {
      _showMessage('This habit no longer exists.');
      context.pop();
      return;
    }
    final loaded = habit;
    setState(() {
      _nameController.text = loaded.name;
      _descriptionController.text = loaded.description;
      _type = loaded.type;
      _colorIndex = AppConstants.habitColors
          .indexOf(Color(loaded.color))
          .clamp(0, AppConstants.habitColors.length - 1)
          .toInt();
      _iconIndex = loaded.iconIndex;
      _categoryId = loaded.categoryId;
      _target = loaded.targetPerDay;
      _reminderEnabled = loaded.reminderEnabled;
      _reminderTime = loaded.reminderTime;
      _originalCreatedAt = loaded.createdAt;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Give your habit a name.');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final habit = Habit(
      id: widget.id,
      name: name,
      description: _descriptionController.text.trim(),
      type: _type,
      color: AppConstants.habitColors[_colorIndex].toARGB32(),
      iconIndex: _iconIndex,
      categoryId: _categoryId,
      targetPerDay: _type == HabitType.good ? _target : 1,
      reminderTime: _reminderEnabled ? (_reminderTime ?? _defaultTime()) : null,
      reminderEnabled: _reminderEnabled,
      createdAt: _originalCreatedAt ?? now.millisecondsSinceEpoch,
    );
    try {
      await ref.read(habitsProvider.notifier).save(habit);
      if (!mounted) return;
      showAppSnackBar(context, _isNew ? 'Habit created.' : 'Habit updated.');
      context.pop();
    } catch (e, st) {
      AppLogger.error('Failed to save habit', e, st);
      _showMessage('Could not save your habit. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _defaultTime() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

  /// Android 13+ shows a system permission prompt the first time; on older
  /// Android it is already granted. If denied, remind the user where to fix
  /// it — the schedule itself still saves either way.
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

  Future<void> _pickReminderTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (picked != null) {
      setState(() {
        _reminderTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _createCategory() async {
    final draft = await showCategoryDialog(
      context,
      colors: AppConstants.habitColors,
    );
    if (draft == null || !mounted) return;
    try {
      final id = await ref.read(categoriesProvider.notifier).add(
            draft.name,
            draft.color.toARGB32(),
            CategoryKind.habit,
          );
      if (mounted) setState(() => _categoryId = id);
    } catch (e, st) {
      AppLogger.error('Failed to create category', e, st);
      _showMessage('Could not create the category.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
            .where((c) => c.kind == CategoryKind.habit)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Habit' : 'Edit Habit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _label('Type'),
          const SizedBox(height: 10),
          SegmentedButton<HabitType>(
            segments: const [
              ButtonSegment(
                value: HabitType.good,
                icon: Icon(Icons.add_circle_outline),
                label: Text('Good habit'),
              ),
              ButtonSegment(
                value: HabitType.bad,
                icon: Icon(Icons.remove_circle_outline),
                label: Text('Bad habit'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: 'Habit name',
              prefixIcon: Icon(Icons.edit),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Why does this matter? (optional)',
              prefixIcon: Icon(Icons.notes),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          _label('Color'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < AppConstants.habitColors.length; i++)
                ColorDot(
                  color: AppConstants.habitColors[i],
                  selected: i == _colorIndex,
                  onTap: () => setState(() => _colorIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _label('Icon'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < AppConstants.habitIcons.length; i++)
                _IconDot(
                  icon: AppConstants.habitIcons[i],
                  color: AppConstants.habitColors[_colorIndex],
                  selected: i == _iconIndex,
                  onTap: () => setState(() => _iconIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _label('Category'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(VyraStyle.of(context).radius),
                    border: VyraStyle.of(context).boxBorder ??
                        Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                  ),
                  child: DropdownButton<int?>(
                    value: _categoryId,
                    hint: const Text('No category'),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('No category')),
                      for (final c in categories)
                        DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _createCategory,
                icon: const Icon(Icons.add),
                tooltip: 'New category',
              ),
            ],
          ),
          if (_type == HabitType.good) ...[
            const SizedBox(height: 20),
            _label('Target per day'),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _target > 1
                      ? () => setState(() => _target--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_target',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _target < 99
                      ? () => setState(() => _target++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'times per day',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _label('Reminder'),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _reminderEnabled,
                  onChanged: (v) {
                    setState(() {
                      _reminderEnabled = v;
                      if (v) _reminderTime ??= _defaultTime();
                    });
                    if (v) _requestReminderPermission();
                  },
                  title: const Text('Enable reminder'),
                  subtitle: const Text('Get a daily nudge at your chosen time'),
                ),
                if (_reminderEnabled) ...[
                  Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text(
                      _reminderTime == null
                          ? 'Set time'
                          : 'Daily at ${_reminderTime!.substring(0, 2)}:${_reminderTime!.substring(3)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickReminderTime,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style:
            Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _IconDot extends StatelessWidget {
  const _IconDot({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VyraStyle.of(context).radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(VyraStyle.of(context).radius),
          border: Border.all(
            color: selected ? color : scheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Icon(icon, size: 20, color: selected ? color : scheme.onSurfaceVariant),
      ),
    );
  }
}
