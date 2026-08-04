import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vyra/core/database/app_database.dart';
import 'package:vyra/data/repositories/journal_repository.dart';
import 'package:vyra/data/repositories/tag_repository.dart';
import 'package:vyra/data/services/backup_service.dart';
import 'package:vyra/domain/models/journal_entry.dart';
import 'package:vyra/domain/models/mood.dart';

/// In-memory BackupStorage so tests never touch the real documents dir.
class MemoryBackupStorage implements BackupStorage {
  final Map<String, String> _files = {};

  Iterable<String> get files => _files.keys;

  void forget(String name) => _files.remove(name);

  @override
  Future<Directory> directory() async => Directory.systemTemp;

  @override
  Future<void> write(String fileName, String contents) async {
    _files[fileName] = contents;
    // Also write a real file so BackupService.restoreFile (which reads from
    // disk) works against this harness.
    final file = File('${Directory.systemTemp.path}/$fileName');
    await file.writeAsString(contents);
  }

  @override
  Future<List<File>> list() async => [
        for (final name in _files.keys) fileFor(name),
      ];

  @override
  Future<void> delete(String path) async {
    _files.remove(path.split(RegExp(r'[\\/]')).last);
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Uses [p.join] (like the real storage) so paths match on Windows, where
  /// mixing separators would otherwise make duplicate-path comparisons fail.
  File fileFor(String name) => File(p.join(Directory.systemTemp.path, name));

  String? contentsOf(String name) => _files[name];
}

void main() {
  late AppDatabase database;
  late TagRepository tags;
  late JournalRepository journals;
  late MemoryBackupStorage storage;
  late BackupService service;

  setUp(() async {
    database = await AppDatabase.openInMemory();
    tags = TagRepository(database.db);
    journals = JournalRepository(database.db, tags);
    storage = MemoryBackupStorage();
    service = BackupService(database.db, storage: storage);
  });

  tearDown(() async {
    // Remove any temp files the harness created so runs don't pollute
    // Directory.systemTemp (filenames are second-granularity timestamps).
    for (final name in storage.files.toList()) {
      final file = storage.fileFor(name);
      if (await file.exists()) await file.delete();
      storage.forget(name);
    }
    await database.close();
  });

  Future<void> insertEntry(String title, {List<String> entryTags = const []}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await journals.insert(
      JournalEntry(
        title: title,
        content: 'Body of $title',
        mood: Mood.happy,
        isFavorite: false,
        entryDate: DateTime(2026, 8, 4),
        createdAt: now,
        updatedAt: now,
      ),
      entryTags,
    );
  }

  test('export then restore round-trips the data', () async {
    await insertEntry('Alpha', entryTags: const ['work']);

    final result = await service.export();
    expect(storage.contentsOf(result.path.split(RegExp(r'[\\/]')).last), isNotNull);

    // Wipe the database to simulate a fresh install.
    await database.db.delete('journal_entries');
    await database.db.delete('tags');
    await database.db.delete('journal_tags');
    expect(await journals.getAll(), isEmpty);

    await service.restoreFile(File(result.path));
    final all = await journals.getAll();
    expect(all, hasLength(1));
    expect(all.first.title, 'Alpha');
    expect(all.first.tags, contains('work'));
  });

  test('restoreFile rejects a backup from a newer schema version', () async {
    final content = await service.snapshot();
    final payload = {
      'app': kBackupAppId,
      'format_version': kBackupFormatVersion,
      'schema_version': 999,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': content.tables,
    };
    await storage.write('future.json', jsonEncode(payload));

    expect(
      () => service.restoreFile(storage.fileFor('future.json')),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
  });

  test('duplicate detection: exporting the same data twice makes one file', () async {
    await insertEntry('Alpha');

    final first = await service.export();
    expect(first.skippedDuplicate, isFalse);

    // Nothing changed since the first export — the second one is a duplicate
    // and must not create a new file.
    final second = await service.export();
    expect(second.skippedDuplicate, isTrue);
    expect(second.path, first.path);
    expect(storage.contentsOf(first.path.split(RegExp(r'[\\/]')).last), isNotNull);
  });

  test('validation catches orphaned habit logs and duplicate ids', () async {
    final base = await service.snapshot();

    // Orphaned habit log (no matching habit).
    final orphaned = BackupContent(tables: {
      ...base.tables,
      'habits': const [],
      'habit_logs': const [
        {'id': 1, 'habit_id': 99, 'date': '2026-08-04', 'count': 1, 'note': '', 'created_at': 0},
      ],
    });
    expect(BackupService.validate(orphaned), contains('missing habit'));

    // Duplicate primary key within a table.
    final dup = BackupContent(tables: {
      ...base.tables,
      'tags': const [
        {'id': 1, 'name': 'a', 'created_at': 0},
        {'id': 1, 'name': 'b', 'created_at': 0},
      ],
    });
    expect(BackupService.validate(dup), contains('duplicate id'));
  });

  test('recovery after failed import keeps current data', () async {
    await insertEntry('Keep me');
    final backupContent = await service.snapshot();

    // A backup with a habit log that references a missing habit must fail
    // (foreign keys are enabled) and must not wipe the current journal.
    final bad = BackupContent(tables: {
      ...backupContent.tables,
      'habits': const [],
      'habit_logs': const [
        {'id': 1, 'habit_id': 42, 'date': '2026-08-04', 'count': 1, 'note': '', 'created_at': 0},
      ],
    });

    await expectLater(service.restore(bad), throwsA(anything));
    final all = await journals.getAll();
    expect(all, hasLength(1));
    expect(all.first.title, 'Keep me');
  });
}
