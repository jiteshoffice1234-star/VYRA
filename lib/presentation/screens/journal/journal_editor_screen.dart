import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/journal/journal_providers.dart';
import '../../application/providers/app_providers.dart';
import '../../application/tags/tag_providers.dart';
import '../../core/theme/vyra_style.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/list_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/mood_selector.dart';
import '../../core/widgets/tag_chip.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/mood.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();

  Mood _mood = Mood.neutral;
  DateTime _entryDate = DateTime.now();
  bool _isFavorite = false;
  int? _originalCreatedAt;
  List<String> _tags = [];
  bool _saving = false;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _loadExisting();
  }

  /// Loads the entry being edited. Falls back to the repository so deep
  /// links opened before the list provider finishes loading still work, and
  /// shows a friendly message instead of silently saving an empty entry.
  Future<void> _loadExisting() async {
    var entry = (ref.read(journalListProvider).valueOrNull ?? const <JournalEntry>[])
        .firstWhereOrNull((e) => e.id == widget.id);
    if (entry == null) {
      try {
        final repo = await ref.read(journalRepositoryProvider.future);
        entry = await repo.getById(widget.id!);
      } catch (e, st) {
        AppLogger.error('Failed to load journal entry for editing', e, st);
      }
    }
    if (!mounted) return;
    if (entry == null) {
      _showMessage('This entry no longer exists.');
      context.pop();
      return;
    }
    setState(() {
      _titleController.text = entry.title;
      _contentController.text = entry.content;
      _mood = entry.mood;
      _entryDate = entry.entryDate;
      _isFavorite = entry.isFavorite;
      _originalCreatedAt = entry.createdAt;
      _tags = [...entry.tags];
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final name = raw.trim();
    if (name.isEmpty || _tags.any((t) => t.toLowerCase() == name.toLowerCase())) {
      _tagController.clear();
      return;
    }
    setState(() => _tags.add(name));
    _tagController.clear();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Give your entry a title first.');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final entry = JournalEntry(
      id: widget.id,
      title: title,
      content: _contentController.text.trim(),
      mood: _mood,
      isFavorite: _isFavorite,
      entryDate: _entryDate,
      createdAt: _originalCreatedAt ?? now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      tags: _tags,
    );
    try {
      await ref.read(journalListProvider.notifier).save(entry, _tags);
      if (!mounted) return;
      showAppSnackBar(context, _isNew ? 'Entry created.' : 'Entry updated.');
      context.pop();
    } catch (e, st) {
      AppLogger.error('Failed to save journal entry', e, st);
      _showMessage('Could not save your entry. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggestions = ref.watch(tagProvider).valueOrNull ?? const [];
    final availableSuggestions =
        suggestions.where((t) => !_tags.contains(t.name)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Journal' : 'Edit Journal'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
            tooltip: _isFavorite ? 'Remove favorite' : 'Favorite',
          ),
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Text('How are you feeling?', style: _labelStyle(context)),
                const SizedBox(height: 10),
                MoodSelector(selected: _mood, onChanged: (m) => setState(() => _mood = m)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Date', style: _labelStyle(context)),
                    const Spacer(),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius:
                          BorderRadius.circular(VyraStyle.of(context).radius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(VyraStyle.of(context).radius),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: scheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              AppDate.formatMedium(_entryDate),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Tags', style: _labelStyle(context)),
                const SizedBox(height: 10),
                if (_tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _tags)
                        TagChip(
                          label: tag,
                          selected: true,
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _tagController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    hintText: 'Add a tag and press enter…',
                    prefixIcon: Icon(Icons.tag),
                    counterText: '',
                  ),
                  onSubmitted: _addTag,
                ),
                if (availableSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in availableSuggestions)
                        TagChip(
                          label: tag.name,
                          onTap: () => setState(() => _tags.add(tag.name)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: 200,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  minLines: 10,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'What’s on your mind?',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.notes, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                // Rebuilds only this footer on every keystroke instead of the
                // whole editor (the content controller carries the state).
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _contentController,
                  builder: (context, value, _) => Text(
                    '${TextUtil.wordCount(value.text)} words · '
                    '${TextUtil.charCount(value.text)} characters',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge
      ?.copyWith(fontWeight: FontWeight.w700);
}
