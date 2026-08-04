import 'package:shared_preferences/shared_preferences.dart';

/// Persists recent search queries (most recent first).
class SearchHistoryRepository {
  SearchHistoryRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'search_history';
  static const int maxEntries = 10;

  List<String> load() => _prefs.getStringList(_key) ?? const [];

  Future<void> save(List<String> entries) =>
      _prefs.setStringList(_key, entries.take(maxEntries).toList());
}
