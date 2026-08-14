import 'checklist_item.dart';

/// How a note renders: plain text or a checklist.
enum NoteType {
  text('text'),
  checklist('checklist');

  const NoteType(this.id);

  final String id;

  static NoteType fromId(String id) =>
      values.firstWhere((t) => t.id == id, orElse: () => NoteType.text);
}

/// A note. `content` holds text for [NoteType.text]; [items] for checklists.
class Note {
  const Note({
    this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.color,
    required this.isPinned,
    required this.isFavorite,
    this.categoryId,
    this.categoryName,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.items = const [],
  });

  final int? id;
  final String title;
  final String content;
  final NoteType type;
  final int color; // ARGB
  final bool isPinned;
  final bool isFavorite;
  final int? categoryId;
  final String? categoryName; // joined from categories
  final int createdAt;
  final int updatedAt;
  final List<String> tags;
  final List<ChecklistItem> items;

  factory Note.fromMap(
    Map<String, Object?> map, {
    List<String> tags = const [],
    List<ChecklistItem> items = const [],
  }) =>
      Note(
        id: map['id'] as int?,
        title: map['title'] as String,
        content: (map['content'] as String?) ?? '',
        type: NoteType.fromId((map['type'] as String?) ?? 'text'),
        color: map['color'] as int,
        isPinned: (map['is_pinned'] as int? ?? 0) == 1,
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        categoryId: map['category_id'] as int?,
        categoryName: map['category_name'] as String?,
        createdAt: map['created_at'] as int,
        updatedAt: map['updated_at'] as int,
        tags: tags,
        items: items,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.id,
        'color': color,
        'is_pinned': isPinned ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
        'category_id': categoryId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Note copyWith({
    int? id,
    String? title,
    String? content,
    NoteType? type,
    int? color,
    bool? isPinned,
    bool? isFavorite,
    int? categoryId,
    String? categoryName,
    int? createdAt,
    int? updatedAt,
    List<String>? tags,
    List<ChecklistItem>? items,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        type: type ?? this.type,
        color: color ?? this.color,
        isPinned: isPinned ?? this.isPinned,
        isFavorite: isFavorite ?? this.isFavorite,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        tags: tags ?? this.tags,
        items: items ?? this.items,
      );

  /// Number of checked items (0 for text notes).
  int get checkedCount => items.where((i) => i.isChecked).length;

  int get completedPercent =>
      items.isEmpty ? 0 : (checkedCount / items.length * 100).round();
}
