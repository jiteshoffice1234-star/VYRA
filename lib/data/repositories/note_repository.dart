import 'package:sqflite/sqflite.dart';

import '../../domain/models/checklist_item.dart';
import '../../domain/models/note.dart';
import 'tag_repository.dart';

class NoteRepository {
  NoteRepository(this._db, this._tags);

  final Database _db;
  final TagRepository _tags;

  Future<List<Note>> getAll() async {
    final rows = await _db.rawQuery('''
      SELECT n.*, c.name AS category_name
      FROM notes n
      LEFT JOIN categories c ON c.id = n.category_id
      ORDER BY n.is_pinned DESC, n.updated_at DESC
    ''');
    final tagMap = await _tags.tagsByNote();
    final itemMap = await _itemsByNote();
    return [
      for (final r in rows)
        Note.fromMap(
          r,
          tags: tagMap[r['id']] ?? const [],
          items: itemMap[r['id']] ?? const [],
        ),
    ];
  }

  Future<Note?> getById(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT n.*, c.name AS category_name
      FROM notes n
      LEFT JOIN categories c ON c.id = n.category_id
      WHERE n.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) return null;
    final tagMap = await _tags.tagsByNote(id: id);
    final itemMap = await _itemsByNote(noteId: id);
    return Note.fromMap(
      rows.first,
      tags: tagMap[id] ?? const [],
      items: itemMap[id] ?? const [],
    );
  }

  /// Inserts the note, its checklist items and tag links in one transaction.
  Future<int> insert(Note note, List<String> tags) async {
    final map = note.toMap()..remove('id');
    return _db.transaction((txn) async {
      final id = await txn.insert('notes', map);
      await _replaceItems(txn, id, note.items);
      if (tags.isNotEmpty) {
        await _tags.linkNoteTx(txn, id, await _tags.ensureTagsTx(txn, tags));
      }
      return id;
    });
  }

  /// Updates the note and atomically replaces its checklist items and tags.
  Future<void> update(Note note, List<String> tags) async {
    final id = note.id;
    if (id == null) return;
    final map = note.toMap()..remove('id');
    await _db.transaction((txn) async {
      await txn.update('notes', map, where: 'id = ?', whereArgs: [id]);
      await txn.delete('note_tags', where: 'note_id = ?', whereArgs: [id]);
      await txn.delete('checklist_items',
          where: 'note_id = ?', whereArgs: [id]);
      await _replaceItems(txn, id, note.items);
      if (tags.isNotEmpty) {
        await _tags.linkNoteTx(txn, id, await _tags.ensureTagsTx(txn, tags));
      }
    });
  }

  Future<void> delete(int id) =>
      _db.delete('notes', where: 'id = ?', whereArgs: [id]);

  Future<void> setPinned(int id, bool pinned) => _db.update(
        'notes',
        {'is_pinned': pinned ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setFavorite(int id, bool favorite) => _db.update(
        'notes',
        {'is_favorite': favorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> _replaceItems(
    DatabaseExecutor db,
    int noteId,
    List<ChecklistItem> items,
  ) async {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await db.insert('checklist_items', {
        'note_id': noteId,
        'text': item.text,
        'is_checked': item.isChecked ? 1 : 0,
        'position': i,
      });
    }
  }

  /// note_id -> checklist items. When [noteId] is given only that note's items
  /// are loaded (used by [getById]) instead of scanning the whole table.
  Future<Map<int, List<ChecklistItem>>> _itemsByNote({int? noteId}) async {
    final rows = noteId == null
        ? await _db.query('checklist_items', orderBy: 'position ASC')
        : await _db.query(
            'checklist_items',
            where: 'note_id = ?',
            whereArgs: [noteId],
            orderBy: 'position ASC',
          );
    final map = <int, List<ChecklistItem>>{};
    for (final r in rows) {
      map.putIfAbsent(r['note_id'] as int, () => []).add(ChecklistItem.fromMap(r));
    }
    return map;
  }
}
