/// What a category is used for.
enum CategoryKind {
  habit('habit'),
  note('note');

  const CategoryKind(this.id);

  final String id;

  static CategoryKind fromId(String id) =>
      values.firstWhere((k) => k.id == id, orElse: () => CategoryKind.note);
}

/// A user-defined category, shared between habits and notes.
class Category {
  const Category({
    this.id,
    required this.name,
    required this.color,
    required this.kind,
  });

  final int? id;
  final String name;
  final int color; // ARGB
  final CategoryKind kind;

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        color: map['color'] as int,
        kind: CategoryKind.fromId(map['kind'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'kind': kind.id,
      };
}
