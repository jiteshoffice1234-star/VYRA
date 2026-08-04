import 'package:sqflite/sqflite.dart';

import '../../domain/models/journal_entry.dart';
import 'tag_repository.dart';

class JournalRepository {
  JournalRepository(this._db, this._tags);

  final Database _db;
  final TagRepository _tags;

  Future<List<JournalEntry>> getAll() async {
    final rows = await _db.query(
      'journal_entries',
      orderBy: 'entry_date DESC, updated_at DESC',
    );
    final tagMap = await _tags.tagsByJournal();
    return [
      for (final r in rows)
        JournalEntry.fromMap(r, tags: tagMap[r['id']] ?? const []),
    ];
  }

  Future<JournalEntry?> getById(int id) async {
    final rows = await _db.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final tagMap = await _tags.tagsByJournal(id: id);
    return JournalEntry.fromMap(rows.first, tags: tagMap[id] ?? const []);
  }

  /// Inserts the entry and its tag links in one transaction.
  Future<int> insert(JournalEntry entry, List<String> tags) async {
    final map = entry.toMap()..remove('id');
    return _db.transaction((txn) async {
      final id = await txn.insert('journal_entries', map);
      if (tags.isNotEmpty) {
        await _tags.linkJournalTx(txn, id, await _tags.ensureTagsTx(txn, tags));
      }
      return id;
    });
  }

  /// Updates the entry and replaces its tag links atomically.
  Future<void> update(JournalEntry entry, List<String> tags) async {
    final id = entry.id;
    if (id == null) return;
    final map = entry.toMap()..remove('id');
    await _db.transaction((txn) async {
      await txn.update(
        'journal_entries',
        map,
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('journal_tags',
          where: 'journal_id = ?', whereArgs: [id]);
      if (tags.isNotEmpty) {
        await _tags.linkJournalTx(txn, id, await _tags.ensureTagsTx(txn, tags));
      }
    });
  }

  Future<void> delete(int id) =>
      _db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);

  Future<void> setFavorite(int id, bool favorite) => _db.update(
        'journal_entries',
        {'is_favorite': favorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// All entry day keys (for calendar markers).
  Future<Set<String>> allJournalDays() async {
    final rows = await _db.query('journal_entries', columns: ['entry_date']);
    return {for (final r in rows) r['entry_date'] as String};
  }
}
