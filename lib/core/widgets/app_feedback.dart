import 'package:flutter/material.dart';

/// Shows a transient [SnackBar], replacing any snackbar currently visible.
///
/// Uses `ScaffoldMessenger.maybeOf` so it can be called from a state whose
/// context may already be deactivated without throwing.
void showAppSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
