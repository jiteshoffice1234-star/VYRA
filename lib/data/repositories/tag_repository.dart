import 'package:sqflite/sqflite.dart';

import '../../domain/models/tag.dart';

/// Manages the shared `tags` table and the `journal_tags` / `note_tags` links.
///
/// Methods accept a [DatabaseExecutor] so callers can run them inside a
/// [Database.transaction] for atomic multi-row writes (entry + tag links).
class TagRepository {
  TagRepository(this._db);

  final Database _db;

  Future<List<Tag>> allTags() async {
    final rows = await _db.query('tags', orderBy: 'name COLLATE NOCASE');
    return [for (final r in rows) Tag.fromMap(r)];
  }

  /// Returns the ids for the given tag names, creating missing ones.
  Future<List<int>> ensureTags(List<String> names) => _ensureTags(_db, names);

  /// Transactional variant of [ensureTags] for use inside a write batch.
  Future<List<int>> ensureTagsTx(Transaction txn, List<String> names) =>
      _ensureTags(txn, names);

  Future<List<int>> _ensureTags(DatabaseExecutor db, List<String> names) async {
    final ids = <int>[];
    final unique =
        names.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet();
    for (final name in unique) {
      ids.add(await _tagId(db, name));
    }
    return ids;
  }

  Future<int> _tagId(DatabaseExecutor db, String name) async {
    final rows = await db.query(
      'tags',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('tags', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// journal_id -> tag names
  Future<Map<int, List<String>>> tagsByJournal({int? id}) =>
      _tagsByOwner(_db, 'journal_tags', 'journal_id', id);

  /// note_id -> tag names
  Future<Map<int, List<String>>> tagsByNote({int? id}) =>
      _tagsByOwner(_db, 'note_tags', 'note_id', id);

  Future<Map<int, List<String>>> _tagsByOwner(
    DatabaseExecutor db,
    String table,
    String ownerColumn,
    int? id,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT jt.$ownerColumn AS owner_id, t.name AS name
      FROM $table jt INNER JOIN tags t ON t.id = jt.tag_id
      ${id == null ? '' : 'WHERE jt.$ownerColumn = ?'}
      ''',
      id == null ? null : [id],
    );
    final map = <int, List<String>>{};
    for (final r in rows) {
      map.putIfAbsent(r['owner_id'] as int, () => []).add(r['name'] as String);
    }
    return map;
  }

  Future<void> linkJournal(int journalId, List<int> tagIds) =>
      _link(_db, 'journal_tags', 'journal_id', journalId, tagIds);

  Future<void> linkJournalTx(
    Transaction txn,
    int journalId,
    List<int> tagIds,
  ) =>
      _link(txn, 'journal_tags', 'journal_id', journalId, tagIds);

  Future<void> linkNote(int noteId, List<int> tagIds) =>
      _link(_db, 'note_tags', 'note_id', noteId, tagIds);

  Future<void> linkNoteTx(Transaction txn, int noteId, List<int> tagIds) =>
      _link(txn, 'note_tags', 'note_id', noteId, tagIds);

  Future<void> _link(
    DatabaseExecutor db,
    String table,
    String ownerColumn,
    int ownerId,
    List<int> tagIds,
  ) async {
    for (final tagId in tagIds) {
      await db.insert(
        table,
        {ownerColumn: ownerId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
