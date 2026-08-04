import 'package:flutter/material.dart';

import '../../core/theme/app_theme_style.dart';

/// User preferences: theme mode, accent seed index and theme style.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedIndex = 0,
    this.themeStyle = AppThemeStyle.modern,
  });

  final ThemeMode themeMode;
  final int seedIndex;
  final AppThemeStyle themeStyle;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedIndex,
    AppThemeStyle? themeStyle,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        seedIndex: seedIndex ?? this.seedIndex,
        themeStyle: themeStyle ?? this.themeStyle,
      );
}
