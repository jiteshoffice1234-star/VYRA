import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/search_history_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/reminder_service.dart';

/// Opens the single app database (lazily, on first watch).
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) {
  return AppDatabase.open();
});

final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SettingsRepository(prefs);
});

final tagRepositoryProvider = FutureProvider<TagRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return TagRepository(db.db);
});

final journalRepositoryProvider = FutureProvider<JournalRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final tags = await ref.watch(tagRepositoryProvider.future);
  return JournalRepository(db.db, tags);
});

final habitRepositoryProvider = FutureProvider<HabitRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return HabitRepository(db.db);
});

final noteRepositoryProvider = FutureProvider<NoteRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final tags = await ref.watch(tagRepositoryProvider.future);
  return NoteRepository(db.db, tags);
});

final categoryRepositoryProvider = FutureProvider<CategoryRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return CategoryRepository(db.db);
});

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return BackupService(db.db);
});

/// Schedules habit reminders. Shares the single instance initialized at
/// startup (see [appReminderScheduler]) so scheduling works even though no
/// platform channels exist in `flutter test` — the provider is only touched
/// when habit save/delete actually needs it.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return appReminderScheduler;
});

final searchHistoryRepositoryProvider =
    FutureProvider<SearchHistoryRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SearchHistoryRepository(prefs);
});
