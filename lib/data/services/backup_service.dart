import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Identifier written into every backup file.
const String kBackupAppId = 'vyra';

/// Current backup file format version. Bump when the file layout changes;
/// old versions remain importable (see [BackupService.importBackup]).
const int kBackupFormatVersion = 1;

/// Table names in parent-first order. Restore clears them in reverse order so
/// foreign-key children (join tables, checklist items) are removed first.
const List<String> kBackupTables = [
  'categories',
  'tags',
  'journal_entries',
  'journal_tags',
  'habits',
  'habit_logs',
  'notes',
  'note_tags',
  'checklist_items',
];

/// The raw table data of a backup, keyed by table name.
class BackupContent {
  const BackupContent({required this.tables});

  final Map<String, List<Map<String, Object?>>> tables;
}

/// Everything the UI needs to describe a backup without restoring it.
class BackupInfo {
  const BackupInfo({
    required this.path,
    required this.exportedAt,
    required this.schemaVersion,
    required this.formatVersion,
    required this.rowCount,
    required this.contentHash,
    required this.valid,
    this.error,
  });

  final String path;
  final DateTime? exportedAt;
  final int schemaVersion;
  final int formatVersion;
  final int rowCount;
  final String contentHash;
  final bool valid;
  final String? error;

  String get fileName => path.split(RegExp(r'[\\/]')).last;
}

/// Result of a duplicate check: the file that already holds the same data.
class DuplicateResult {
  const DuplicateResult({this.existingPath});

  /// Path of the backup that already contains the identical data, if any.
  final String? existingPath;

  bool get isDuplicate => existingPath != null;
}

/// Result of an export: where the file went and whether it was skipped
/// because an identical backup already exists.
class ExportResult {
  const ExportResult({required this.path, this.skippedDuplicate = false});

  final String path;
  final bool skippedDuplicate;
}

/// Contract for storing / loading backup files. The local implementation
/// writes to the app documents directory; a future cloud sync can implement
/// the same interface without touching the import/restore logic.
abstract interface class BackupStorage {
  Future<Directory> directory();
  Future<void> write(String fileName, String contents);
  Future<List<File>> list();
  Future<void> delete(String path);
}

/// Default on-device storage under `<documents>/vyra_backups/`.
class LocalBackupStorage implements BackupStorage {
  @override
  Future<Directory> directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'vyra_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<void> write(String fileName, String contents) async {
    final file = File(p.join((await directory()).path, fileName));
    await file.writeAsString(contents, flush: true);
  }

  @override
  Future<List<File>> list() async {
    final dir = await directory();
    if (!await dir.exists()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.json')
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

/// Complete local backup system: export, import, restore, validation,
/// duplicate detection and recovery. Everything stays on device.
///
/// Restores run inside a transaction: a malformed file or a failing row
/// rolls the database back to its previous state automatically (recovery
/// after failed import). Backups carry schema + format versions so a backup
/// from a newer app version is rejected with a clear message instead of
/// silently corrupting data.
class BackupService {
  BackupService(this._db, {BackupStorage? storage})
      : _storage = storage ?? LocalBackupStorage();

  final Database _db;
  final BackupStorage _storage;

  Future<int> get schemaVersion async =>
      await _db.getVersion() as int;

  /// The full current database as a portable content object.
  Future<BackupContent> snapshot() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in kBackupTables) {
      tables[table] = await _db.query(table, orderBy: 'rowid');
    }
    return BackupContent(tables: tables);
  }

  /// A stable fingerprint of the content, used for duplicate detection.
  ///
  /// Self-contained (FNV-1a over the canonical JSON) so no crypto dependency
  /// is needed; uniqueness is all that matters here, not security.
  static String hashOf(BackupContent content) {
    var hash = 0x811C9DC5;
    final bytes = utf8.encode(jsonEncode(content.tables));
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Writes a full snapshot to a timestamped JSON file. When an identical
  /// backup already exists, no file is written and the existing path is
  /// returned with [ExportResult.skippedDuplicate] set — no duplicate files.
  Future<ExportResult> export() async {
    final content = await snapshot();
    final duplicate = await findDuplicate(content);
    if (duplicate.isDuplicate) {
      return ExportResult(
        path: duplicate.existingPath!,
        skippedDuplicate: true,
      );
    }
    final hash = hashOf(content);
    final fileName = 'vyra_backup_${_timestamp()}.json';
    await _storage.write(fileName, await _encode(content, hash));
    return ExportResult(
      path: p.join((await _storage.directory()).path, fileName),
    );
  }

  /// Whether an identical backup already exists (same content hash).
  Future<DuplicateResult> findDuplicate(BackupContent content) async {
    final want = hashOf(content);
    for (final file in await _storage.list()) {
      final info = await inspect(file);
      if (info.valid && info.contentHash == want) {
        return DuplicateResult(existingPath: file.path);
      }
    }
    return const DuplicateResult();
  }

  /// Existing backups, newest first, with metadata and validity.
  Future<List<BackupInfo>> listBackups() async {
    final files = await _storage.list();
    final out = <BackupInfo>[];
    for (final file in files) {
      out.add(await inspect(file));
    }
    return out;
  }

  /// Reads and validates a backup file without restoring it.
  Future<BackupInfo> inspect(File file) async {
    final BackupContent? content;
    final Map<String, Object?>? meta;
    try {
      final decoded = _decode(await file.readAsString());
      content = decoded.$1;
      meta = decoded.$2;
    } on BackupException catch (e) {
      return BackupInfo(
        path: file.path,
        exportedAt: null,
        schemaVersion: 0,
        formatVersion: 0,
        rowCount: 0,
        contentHash: '',
        valid: false,
        error: e.message,
      );
    }
    final error = validate(content!);
    return BackupInfo(
      path: file.path,
      exportedAt: _parseDate(meta?['exported_at'] as String?),
      schemaVersion: meta?['schema_version'] as int? ?? 0,
      formatVersion: meta?['format_version'] as int? ?? 0,
      rowCount: _rowCount(content),
      contentHash: hashOf(content),
      valid: error == null,
      error: error,
    );
  }

  /// Structural validation: every table present, rows well-formed, no
  /// duplicate primary keys, and no orphaned foreign keys.
  static String? validate(BackupContent content) {
    for (final table in kBackupTables) {
      final rows = content.tables[table];
      if (rows == null) return 'The backup is missing the "$table" table.';
      final ids = <int>{};
      for (final row in rows) {
        if (row is! Map<String, Object?>) {
          return 'The "$table" table has invalid rows.';
        }
        final id = row['id'];
        if (id is int && !ids.add(id)) {
          return 'The "$table" table contains duplicate id $id.';
        }
      }
    }
    return _checkForeignKeys(content);
  }

  static String? _checkForeignKeys(BackupContent content) {
    bool hasId(String table, int id) =>
        content.tables[table]?.any((r) => r['id'] == id) ?? false;

    for (final row in content.tables['journal_tags'] ?? const []) {
      final jid = row['journal_id'] as int?;
      final tid = row['tag_id'] as int?;
      if (jid != null &&
          tid != null &&
          (!hasId('journal_entries', jid) || !hasId('tags', tid))) {
        return 'A journal tag link points to a missing entry or tag.';
      }
    }
    for (final row in content.tables['note_tags'] ?? const []) {
      final nid = row['note_id'] as int?;
      final tid = row['tag_id'] as int?;
      if (nid != null &&
          tid != null &&
          (!hasId('notes', nid) || !hasId('tags', tid))) {
        return 'A note tag link points to a missing note or tag.';
      }
    }
    for (final row in content.tables['habit_logs'] ?? const []) {
      final hid = row['habit_id'] as int?;
      if (hid != null && !hasId('habits', hid)) {
        return 'A habit log points to a missing habit.';
      }
    }
    for (final row in content.tables['checklist_items'] ?? const []) {
      final nid = row['note_id'] as int?;
      if (nid != null && !hasId('notes', nid)) {
        return 'A checklist item points to a missing note.';
      }
    }
    for (final row in content.tables['habits'] ?? const []) {
      final cid = row['category_id'] as int?;
      if (cid != null && !hasId('categories', cid)) {
        return 'A habit points to a missing category.';
      }
    }
    for (final row in content.tables['notes'] ?? const []) {
      final cid = row['category_id'] as int?;
      if (cid != null && !hasId('categories', cid)) {
        return 'A note points to a missing category.';
      }
    }
    return null;
  }

  /// Restores [content]. The import runs inside a database transaction, so a
  /// malformed row or constraint violation rolls the whole operation back and
  /// the previous data stays intact (recovery after failed import).
  Future<void> restore(BackupContent content) => _import(content);

  /// Restores from a file (parses, validates, then [restore]).
  Future<void> restoreFile(File file) async {
    final (content, meta) = _decode(await file.readAsString());
    final schema = meta?['schema_version'] as int? ?? 0;
    final format = meta?['format_version'] as int? ?? 0;
    final current = await schemaVersion;
    if (schema > current || format > kBackupFormatVersion) {
      throw BackupException(
        'This backup was made by a newer version of VYRA. '
        'Update the app to restore it.',
      );
    }
    final error = validate(content);
    if (error != null) throw BackupException(error);
    await restore(content);
  }

  Future<void> _import(BackupContent content) {
    return _db.transaction((txn) async {
      // Children first, then parents, so no FK constraint fires mid-clear.
      for (final table in kBackupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in kBackupTables) {
        final rows = content.tables[table] ?? const [];
        for (final row in rows) {
          await txn.insert(table, row);
        }
      }
    });
  }

  /// Deletes one backup file.
  Future<void> deleteBackup(String path) => _storage.delete(path);

  Future<String> _encode(BackupContent content, String hash) async {
    final payload = {
      'app': kBackupAppId,
      'format_version': kBackupFormatVersion,
      'schema_version': await schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'content_hash': hash,
      'tables': content.tables,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Coerces a decoded table value to a row list, rejecting non-list values
  /// with a [BackupException] so malformed-but-valid JSON files degrade to a
  /// friendly error instead of crashing with a TypeError.
  static List<dynamic> _tableRows(String table, Object? value) {
    if (value is List) return value;
    throw BackupException('The "$table" table has invalid rows.');
  }

  /// Parses and validates the envelope. Returns (content, metadata).
  (BackupContent, Map<String, Object?>?) _decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw BackupException('The file is not valid JSON (${e.message}).');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupException('The backup file has an unexpected format.');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const BackupException('The backup file contains no table data.');
    }
    final content = BackupContent(tables: {
      for (final e in tables.entries)
        e.key: [
          for (final row in _tableRows(e.key, e.value))
            if (row is Map<String, dynamic>)
              row
            else
              throw BackupException(
                'The "${e.key}" table has invalid rows.',
              ),
        ],
    });
    final meta = <String, Object?>{
      if (decoded['app'] != null) 'app': decoded['app']!,
      if (decoded['format_version'] != null)
        'format_version': decoded['format_version']!,
      if (decoded['schema_version'] != null)
        'schema_version': decoded['schema_version']!,
      if (decoded['exported_at'] != null)
        'exported_at': decoded['exported_at']!,
    };
    return (content, meta);
  }

  static DateTime? _parseDate(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);

  static int _rowCount(BackupContent content) => kBackupTables.fold(
        0,
        (sum, t) => sum + (content.tables[t]?.length ?? 0),
      );

  static String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

}

/// A user-facing backup problem (bad file, missing table, invalid rows).
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
