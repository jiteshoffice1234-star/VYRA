import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/journal/journal_providers.dart';
import '../../core/theme/mood_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/list_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/tag_chip.dart';
import '../../domain/models/journal_entry.dart';

class JournalDetailScreen extends ConsumerWidget {
  const JournalDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(journalListProvider);
    final entry = list.valueOrNull?.firstWhereOrNull((e) => e.id == id);

    if (list.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: Icons.search_off,
          title: 'Entry not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    }

    final moodColor = entry.mood.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(journalListProvider.notifier).toggleFavorite(id),
            icon: Icon(
              entry.isFavorite ? Icons.star : Icons.star_border,
              color: entry.isFavorite ? Colors.amber : scheme.onSurfaceVariant,
            ),
            tooltip: entry.isFavorite ? 'Remove favorite' : 'Favorite',
          ),
          IconButton(
            onPressed: () => context.push('/journal/editor?id=$id'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: moodColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(entry.mood.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.mood.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, color: moodColor),
                    ),
                    Text(
                      AppDate.formatFull(entry.entryDate),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tag in entry.tags) TagChip(label: tag)],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            entry.title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            entry.content.isEmpty ? 'No content.' : entry.content,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.6, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.notes,
                label: '${TextUtil.wordCount(entry.content)} words',
              ),
              _MetaChip(
                icon: Icons.text_fields,
                label: '${TextUtil.charCount(entry.content)} chars',
              ),
              _MetaChip(
                icon: Icons.history,
                label: 'Updated ${AppDate.formatShort(
                  DateTime.fromMillisecondsSinceEpoch(entry.updatedAt),
                )}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Delete entry?',
      message: 'This journal entry will be permanently removed.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(journalListProvider.notifier).delete(id);
    } catch (e, st) {
      AppLogger.error('Failed to delete journal entry', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not delete the entry.');
      }
      return;
    }
    if (context.mounted) context.pop();
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
