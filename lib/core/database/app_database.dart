import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Central SQLite database for VYRA. Offline-first, no network calls.
///
/// Uses `sqflite_common_ffi` on desktop so the same code runs on
/// Windows / macOS / Linux for local testing.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// Current schema version. Bump this and add an `onUpgrade` step whenever
  /// the schema changes so existing installs migrate safely.
  static const int _version = 3;
  static AppDatabase? _instance;

  /// Opens the app database (singleton). Safe to call multiple times.
  static Future<AppDatabase> open() async {
    final existing = _instance;
    if (existing != null) return existing;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'vyra.db');
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          _upgradeSchema(db, oldVersion, newVersion),
    );
    _instance = AppDatabase._(db);
    return _instance!;
  }

  /// Opens an in-memory database (used by tests).
  static Future<AppDatabase> openInMemory() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            _upgradeSchema(db, oldVersion, newVersion),
      ),
    );
    return AppDatabase._(db);
  }

  /// Runs versioned migrations. Each future migration is guarded by its own
  /// version check so upgrades are additive and idempotent:
  ///
  /// ```dart
  /// if (oldVersion < 3) {
  ///   await db.execute('ALTER TABLE ...');
  /// }
  /// ```
  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v3: AI conversation history and usage tracking tables.
    if (oldVersion < 3) {
      await _createAiSchema(db);
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        kind TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        mood TEXT NOT NULL DEFAULT 'neutral',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        entry_date TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE journal_tags (
        journal_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (journal_id, tag_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'good',
        color INTEGER NOT NULL,
        icon_index INTEGER NOT NULL DEFAULT 0,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        target_per_day INTEGER NOT NULL DEFAULT 1,
        reminder_time TEXT,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        UNIQUE (habit_id, date)
      )
    ''');
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'text',
        color INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE note_tags (
        note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (note_id, tag_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE checklist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        text TEXT NOT NULL,
        is_checked INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_journal_entry_date ON journal_entries(entry_date)');
    await db.execute(
        'CREATE INDEX idx_habit_logs_habit ON habit_logs(habit_id, date)');
    await db.execute('CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
    await db.execute('CREATE INDEX idx_checklist_note ON checklist_items(note_id)');
    await _createAiSchema(db);
  }

  /// AI conversation history + usage tables (schema v3).
  static Future<void> _createAiSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        model TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        tokens INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER REFERENCES ai_conversations(id) ON DELETE SET NULL,
        service_id TEXT NOT NULL,
        model TEXT,
        prompt_tokens INTEGER NOT NULL DEFAULT 0,
        completion_tokens INTEGER NOT NULL DEFAULT 0,
        latency_ms INTEGER NOT NULL DEFAULT 0,
        streamed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation ON ai_messages(conversation_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_usage_created ON ai_usage(created_at)');
  }

  /// Clears the cached singleton so the next [open] reopens the database.
  /// Used by tests and by a future in-app reset flow.
  static void resetForTesting() => _instance = null;

  /// Closes the underlying connection and forgets the cached singleton.
  Future<void> close() async {
    await db.close();
    if (identical(_instance, this)) _instance = null;
  }
}
