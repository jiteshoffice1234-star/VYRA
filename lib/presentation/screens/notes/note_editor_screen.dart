import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/categories/category_providers.dart';
import '../../application/notes/note_providers.dart';
import '../../application/providers/app_providers.dart';
import '../../application/tags/tag_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/vyra_style.dart';
import '../../core/utils/list_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/category_dialog.dart';
import '../../core/widgets/color_dot.dart';
import '../../core/widgets/tag_chip.dart';
import '../../domain/models/category.dart';
import '../../domain/models/checklist_item.dart';
import '../../domain/models/note.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final _itemController = TextEditingController();

  NoteType _type = NoteType.text;
  int _colorIndex = 0;
  int? _categoryId;
  bool _isPinned = false;
  bool _isFavorite = false;
  int? _originalCreatedAt;
  List<String> _tags = [];
  List<ChecklistItem> _items = [];
  bool _saving = false;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _loadExisting();
  }

  /// Loads the note being edited, falling back to the repository so deep
  /// links opened before the list finishes loading still work.
  Future<void> _loadExisting() async {
    var note = (ref.read(notesProvider).valueOrNull ?? const <Note>[])
        .firstWhereOrNull((n) => n.id == widget.id);
    if (note == null) {
      try {
        final repo = await ref.read(noteRepositoryProvider.future);
        note = await repo.getById(widget.id!);
      } catch (e, st) {
        AppLogger.error('Failed to load note for editing', e, st);
      }
    }
    if (!mounted) return;
    if (note == null) {
      _showMessage('This note no longer exists.');
      context.pop();
      return;
    }
    setState(() {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _type = note.type;
      _colorIndex = AppConstants.noteColors
          .indexOf(Color(note.color))
          .clamp(0, AppConstants.noteColors.length - 1)
          .toInt();
      _categoryId = note.categoryId;
      _isPinned = note.isPinned;
      _isFavorite = note.isFavorite;
      _originalCreatedAt = note.createdAt;
      _tags = [...note.tags];
      _items = [for (final i in note.items) i.copyWith()];
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _itemController.dispose();
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

  void _addItem(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(ChecklistItem(text: text, isChecked: false, position: _items.length));
    });
    _itemController.clear();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Give your note a title first.');
      return;
    }
    if (_type == NoteType.checklist && _items.isEmpty) {
      _showMessage('Add at least one checklist item.');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final note = Note(
      id: widget.id,
      title: title,
      content: _type == NoteType.text ? _contentController.text.trim() : '',
      type: _type,
      color: AppConstants.noteColors[_colorIndex].toARGB32(),
      isPinned: _isPinned,
      isFavorite: _isFavorite,
      categoryId: _categoryId,
      createdAt: _originalCreatedAt ?? now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      tags: _tags,
      items: _type == NoteType.checklist ? _items : const [],
    );
    try {
      await ref.read(notesProvider.notifier).save(note, _tags);
      if (!mounted) return;
      showAppSnackBar(context, _isNew ? 'Note created.' : 'Note updated.');
      context.pop();
    } catch (e, st) {
      AppLogger.error('Failed to save note', e, st);
      _showMessage('Could not save your note. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

  Future<void> _createCategory() async {
    final draft = await showCategoryDialog(
      context,
      colors: AppConstants.noteColors,
    );
    if (draft == null || !mounted) return;
    try {
      final id = await ref.read(categoriesProvider.notifier).add(
            draft.name,
            draft.color.toARGB32(),
            CategoryKind.note,
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
    final noteColor = AppConstants.noteColors[_colorIndex];
    final categories =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
            .where((c) => c.kind == CategoryKind.note)
            .toList();
    final suggestions =
        (ref.watch(tagProvider).valueOrNull ?? const []).where(
      (t) => !_tags.contains(t.name),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isPinned = !_isPinned),
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? scheme.primary : null,
            ),
            tooltip: _isPinned ? 'Unpin' : 'Pin',
          ),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedButton<NoteType>(
            segments: const [
              ButtonSegment(
                value: NoteType.text,
                icon: Icon(Icons.text_fields),
                label: Text('Text'),
              ),
              ButtonSegment(
                value: NoteType.checklist,
                icon: Icon(Icons.checklist),
                label: Text('Checklist'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            maxLength: 120,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Note title',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          if (_type == NoteType.text) ...[
            TextField(
              controller: _contentController,
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Write something…',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: noteColor.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(VyraStyle.of(context).radius),
                border: VyraStyle.of(context).border ??
                    Border.all(color: noteColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _ChecklistRow(
                      item: _items[i],
                      color: noteColor,
                      onChanged: (checked) => setState(() {
                        _items[i] = _items[i].copyWith(isChecked: checked);
                      }),
                      onDeleted: () => setState(() => _items.removeAt(i)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: TextField(
                      controller: _itemController,
                      textInputAction: TextInputAction.done,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Add an item and press enter…',
                        filled: false,
                        prefixIcon: Icon(Icons.add_circle_outline, color: noteColor),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                      ),
                      onSubmitted: _addItem,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _label('Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < AppConstants.noteColors.length; i++)
                ColorDot(
                  color: AppConstants.noteColors[i],
                  selected: i == _colorIndex,
                  onTap: () => setState(() => _colorIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Category'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(VyraStyle.of(context).radius),
                    border: VyraStyle.of(context).border ??
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
          const SizedBox(height: 16),
          _label('Tags'),
          const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in suggestions)
                  TagChip(
                    label: tag.name,
                    onTap: () => setState(() => _tags.add(tag.name)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rich text formatting will be available in a future update.',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.color,
    required this.onChanged,
    required this.onDeleted,
  });

  final ChecklistItem item;
  final Color color;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Checkbox(
          value: item.isChecked,
          activeColor: color,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Text(
            item.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration:
                      item.isChecked ? TextDecoration.lineThrough : null,
                  color: item.isChecked
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
          ),
        ),
        IconButton(
          onPressed: onDeleted,
          icon: const Icon(Icons.close, size: 18),
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

