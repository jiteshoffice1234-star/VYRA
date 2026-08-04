import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Route all uncaught framework errors through the logger. In debug builds
  // the red screen is still presented; in release the app degrades gracefully.
  FlutterError.onError = (details) {
    AppLogger.error(
      'Unhandled framework error',
      details.exception,
      details.stack,
    );
    if (kDebugMode) FlutterError.presentError(details);
  };

  // Catches errors that escape the Flutter zone entirely.
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Unhandled platform error', error, stack);
    return true;
  };

  runApp(const ProviderScope(child: VyraApp()));
}
