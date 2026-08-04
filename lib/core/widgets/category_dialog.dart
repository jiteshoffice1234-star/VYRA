import 'package:flutter/material.dart';

/// Result of the "new category" dialog: a trimmed name and a color.
typedef CategoryDraft = ({String name, Color color});

/// Shows the shared "new category" dialog.
///
/// Returns a [CategoryDraft] when the user confirms with a non-empty name,
/// or `null` when the dialog is dismissed.
Future<CategoryDraft?> showCategoryDialog(
  BuildContext context, {
  required List<Color> colors,
}) async {
  if (colors.isEmpty) return null;
  final controller = TextEditingController();
  var color = colors.first;
  final created = await showDialog<CategoryDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('New category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              buildCounter: _noCounter,
              decoration: const InputDecoration(hintText: 'Category name'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final c in colors)
                  InkWell(
                    onTap: () => setDialogState(() => color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: c == color
                            ? Border.all(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .onSurface,
                                width: 2.5,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop((name: name, color: color));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return created;
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  int? maxLength,
}) =>
    null;
