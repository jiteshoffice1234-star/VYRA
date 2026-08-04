import 'package:sqflite/sqflite.dart';

import '../../domain/models/category.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final Database _db;

  Future<List<Category>> getAll({CategoryKind? kind}) async {
    final rows = kind == null
        ? await _db.query('categories', orderBy: 'name COLLATE NOCASE')
        : await _db.query(
            'categories',
            where: 'kind = ?',
            whereArgs: [kind.id],
            orderBy: 'name COLLATE NOCASE',
          );
    return [for (final r in rows) Category.fromMap(r)];
  }

  Future<int> insert(String name, int color, CategoryKind kind) => _db.insert(
        'categories',
        {
          'name': name,
          'color': color,
          'kind': kind.id,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

  Future<void> delete(int id) =>
      _db.delete('categories', where: 'id = ?', whereArgs: [id]);
}
