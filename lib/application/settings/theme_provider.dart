import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme_style.dart';
import '../providers/app_providers.dart';
import 'app_settings.dart';

final themeProvider =
    AsyncNotifierProvider<ThemeNotifier, AppSettings>(ThemeNotifier.new);

class ThemeNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    return repo.load();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final next = (state.valueOrNull ?? const AppSettings())
        .copyWith(themeMode: mode);
    await repo.save(next);
    state = AsyncData(next);
  }

  Future<void> setSeedIndex(int index) async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final next = (state.valueOrNull ?? const AppSettings())
        .copyWith(seedIndex: index);
    await repo.save(next);
    state = AsyncData(next);
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final next = (state.valueOrNull ?? const AppSettings())
        .copyWith(themeStyle: style);
    await repo.save(next);
    state = AsyncData(next);
  }
}
