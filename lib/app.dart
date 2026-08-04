import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/settings/app_settings.dart';
import 'application/settings/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class VyraApp extends ConsumerWidget {
  const VyraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(themeProvider).valueOrNull ?? const AppSettings();
    final seed =
        AppConstants.seedColors[settings.seedIndex % AppConstants.seedColors.length];

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
