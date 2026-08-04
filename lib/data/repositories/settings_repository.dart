import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/settings/app_settings.dart';
import '../../core/theme/app_theme_style.dart';

/// Persists theme preferences with shared_preferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _modeKey = 'theme_mode';
  static const _seedKey = 'seed_index';
  static const _styleKey = 'theme_style';

  AppSettings load() {
    final mode = switch (_prefs.getString(_modeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppSettings(
      themeMode: mode,
      seedIndex: _prefs.getInt(_seedKey) ?? 0,
      themeStyle: AppThemeStyle.fromId(_prefs.getString(_styleKey) ?? ''),
    );
  }

  Future<void> save(AppSettings settings) async {
    final mode = switch (settings.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await _prefs.setString(_modeKey, mode);
    await _prefs.setInt(_seedKey, settings.seedIndex);
    await _prefs.setString(_styleKey, settings.themeStyle.id);
  }
}
