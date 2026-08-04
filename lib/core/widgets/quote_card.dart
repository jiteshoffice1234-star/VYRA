import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/vyra_style.dart';

/// Premium gradient card showing a motivational quote.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VyraStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(style.radius),
        color: style.quoteGradient ? null : scheme.primaryContainer,
        gradient: style.quoteGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.secondaryContainer.withValues(alpha: 0.7),
                ],
              )
            : null,
        border: style.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 30, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            '“${quote.text}”',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            '— ${quote.author}',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
