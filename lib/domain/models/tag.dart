/// A globally shared tag (unique by name).
class Tag {
  const Tag({this.id, required this.name, required this.createdAt});

  final int? id;
  final String name;
  final int createdAt;

  factory Tag.fromMap(Map<String, Object?> map) => Tag(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt: map['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
      };
}
