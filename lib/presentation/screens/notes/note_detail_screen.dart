import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/notes/note_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/list_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../domain/models/note.dart';

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(notesProvider);
    final note = list.valueOrNull?.firstWhereOrNull((n) => n.id == id);

    if (list.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: Icons.search_off,
          title: 'Note not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    }

    final color = Color(note.color);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            onPressed: () => ref.read(notesProvider.notifier).togglePin(id),
            icon: Icon(
              note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: note.isPinned ? scheme.primary : null,
            ),
            tooltip: note.isPinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            onPressed: () => ref.read(notesProvider.notifier).toggleFavorite(id),
            icon: Icon(
              note.isFavorite ? Icons.star : Icons.star_border,
              color: note.isFavorite ? Colors.amber : null,
            ),
            tooltip: note.isFavorite ? 'Remove favorite' : 'Favorite',
          ),
          IconButton(
            onPressed: () => context.push('/note/editor?id=$id'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.1),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                if (note.categoryName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      note.categoryName!,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  'Updated ${AppDate.formatShort(
                    DateTime.fromMillisecondsSinceEpoch(note.updatedAt),
                  )}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              note.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 12),
            if (note.type == NoteType.text)
              Text(
                note.content.isEmpty ? 'No content.' : note.content,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.6, color: scheme.onSurfaceVariant),
              )
            else ...[
              for (final item in note.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          item.isChecked
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: item.isChecked ? color : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.text,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                height: 1.4,
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isChecked
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in note.tags) TagChip(label: tag)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Delete note?',
      message: 'This note will be permanently removed.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(notesProvider.notifier).delete(id);
    } catch (e, st) {
      AppLogger.error('Failed to delete note', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not delete the note.');
      }
      return;
    }
    if (context.mounted) context.pop();
  }
}
