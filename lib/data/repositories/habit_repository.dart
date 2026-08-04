import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_utils.dart';
import '../../domain/models/habit.dart';

class HabitRepository {
  HabitRepository(this._db);

  final Database _db;

  /// Lists habits. Archived habits are hidden unless [includeArchived] is set.
  Future<List<Habit>> getAll({bool includeArchived = false}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT h.*, c.name AS category_name
      FROM habits h
      LEFT JOIN categories c ON c.id = h.category_id
      ${includeArchived ? '' : 'WHERE h.archived = 0'}
      ORDER BY h.created_at DESC
      ''',
    );
    return [for (final r in rows) Habit.fromMap(r)];
  }

  /// Archives or restores a habit without touching its history.
  Future<void> setArchived(int id, bool archived) => _db.update(
        'habits',
        {'archived': archived ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<Habit?> getById(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT h.*, c.name AS category_name
      FROM habits h
      LEFT JOIN categories c ON c.id = h.category_id
      WHERE h.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return Habit.fromMap(rows.first);
  }

  Future<int> insert(Habit habit) =>
      _db.insert('habits', habit.toMap()..remove('id'));

  Future<void> update(Habit habit) => _db.update(
        'habits',
        habit.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [habit.id],
      );

  Future<void> delete(int id) =>
      _db.delete('habits', where: 'id = ?', whereArgs: [id]);

  /// habit_id -> (dayKey -> count)
  Future<Map<int, Map<String, int>>> countsGrouped() async {
    final rows = await _db.rawQuery(
      'SELECT habit_id, date, count FROM habit_logs',
    );
    final map = <int, Map<String, int>>{};
    for (final r in rows) {
      final habitId = r['habit_id'] as int;
      map.putIfAbsent(habitId, () => {})[r['date'] as String] = r['count'] as int;
    }
    return map;
  }

  /// dayKey -> count for one habit.
  Future<Map<String, int>> countsForHabit(int habitId) async {
    final rows = await _db.query(
      'habit_logs',
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
    return {for (final r in rows) r['date'] as String: r['count'] as int};
  }

  /// Upserts the count for a habit on a given day.
  Future<void> setCount(int habitId, DateTime day, int count) => _db.insert(
        'habit_logs',
        {
          'habit_id': habitId,
          'date': AppDate.dayKey(day),
          'count': count < 0 ? 0 : count,
          'note': '',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
