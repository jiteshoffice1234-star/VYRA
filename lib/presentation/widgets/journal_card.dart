import 'package:flutter/material.dart';

import '../../core/theme/mood_colors.dart';
import '../../core/theme/vyra_style.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/tag_chip.dart';
import '../../domain/models/journal_entry.dart';
import '../../core/utils/date_utils.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onFavoriteToggle,
  });

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final moodColor = entry.mood.color;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: moodColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(style.radius),
                    ),
                    child: Center(
                      child: Text(entry.mood.emoji, style: const TextStyle(fontSize: 22)),
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
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppDate.formatMedium(entry.entryDate)} · ${TextUtil.wordCount(entry.content)} words',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onFavoriteToggle,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        entry.isFavorite ? Icons.star : Icons.star_border,
                        key: ValueKey(entry.isFavorite),
                        color: entry.isFavorite ? Colors.amber : scheme.onSurfaceVariant,
                      ),
                    ),
                    tooltip: entry.isFavorite ? 'Remove favorite' : 'Favorite',
                  ),
                ],
              ),
              if (entry.content.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  TextUtil.excerpt(entry.content, maxChars: 160),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final tag in entry.tags) TagChip(label: tag)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
