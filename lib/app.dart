import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/settings/app_settings.dart';
import 'application/settings/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/reminder_service.dart';

class VyraApp extends ConsumerStatefulWidget {
  const VyraApp({super.key});

  @override
  ConsumerState<VyraApp> createState() => _VyraAppState();
}

class _VyraAppState extends ConsumerState<VyraApp> {
  @override
  void initState() {
    super.initState();
    pendingReminderRoute.addListener(_consumePendingReminderRoute);
    // A cold-start notification tap can arrive before the first frame;
    // re-check after the router's navigator is attached.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _consumePendingReminderRoute());
  }

  @override
  void dispose() {
    pendingReminderRoute.removeListener(_consumePendingReminderRoute);
    super.dispose();
  }

  /// Opens the habit a reminder was tapped for, exactly once. Runs after the
  /// current frame so the navigator is always attached (app running or
  /// freshly launched); unknown routes fall through to the error screen.
  void _consumePendingReminderRoute() {
    final route = pendingReminderRoute.value;
    if (route == null || !mounted) return;
    pendingReminderRoute.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) appRouter.go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(themeProvider).valueOrNull ?? const AppSettings();
    final seed = AppConstants.seedColors[
        settings.seedIndex % AppConstants.seedColors.length];

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forStyle(settings.themeStyle, Brightness.light, seed),
      darkTheme: AppTheme.forStyle(settings.themeStyle, Brightness.dark, seed),
      themeMode: settings.themeMode,
      routerConfig: appRouter,
    );
  }
}
