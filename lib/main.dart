import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/logger.dart';
import 'data/services/reminder_service.dart';

Future<void> main() async {
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

  // Habit reminders: initialize once and route notification taps to the
  // habit's detail screen (handled by VyraApp once the router is attached).
  final reminders = appReminderScheduler;
  await reminders.initialize(onTap: (payload) {
    final id = int.tryParse(payload);
    if (id != null) pendingReminderRoute.value = '/habit/detail/$id';
  });
  // Cold start: the app was launched by tapping a reminder notification.
  final launchPayload = await reminders.launchPayload();
  final launchId = int.tryParse(launchPayload ?? '');
  if (launchId != null) pendingReminderRoute.value = '/habit/detail/$launchId';

  runApp(const ProviderScope(child: VyraApp()));
}
