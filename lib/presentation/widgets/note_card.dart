import 'package:flutter/material.dart';

import '../../core/theme/vyra_style.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/models/note.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    final color = Color(note.color);
    final titleStyle = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(style.radius),
        side: style.border ??
            BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          // mainAxisSize.max + Expanded keeps content inside the fixed-height
          // grid cells of the notes screen (no RenderFlex overflow).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned) ...[
                    Icon(Icons.push_pin, size: 16, color: color),
                    const SizedBox(width: 4),
                  ],
                  if (note.isFavorite) ...[
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                  ],
                  const Spacer(),
                  if (note.categoryName != null)
                    Text(
                      note.categoryName!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
              const SizedBox(height: 6),
              Expanded(
                child: note.type == NoteType.text
                    ? Text(
                        TextUtil.excerpt(note.content, maxChars: 90),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${note.checkedCount}/${note.items.length} done',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: note.items.isEmpty
                                  ? 0.0
                                  : note.checkedCount / note.items.length,
                              minHeight: 5,
                              color: color,
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
