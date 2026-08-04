import '../../core/utils/date_utils.dart';
import 'mood.dart';

/// A daily journal entry.
class JournalEntry {
  const JournalEntry({
    this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.isFavorite,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  final int? id;
  final String title;
  final String content;
  final Mood mood;
  final bool isFavorite;
  final DateTime entryDate;
  final int createdAt;
  final int updatedAt;
  final List<String> tags;

  factory JournalEntry.fromMap(
    Map<String, Object?> map, {
    List<String> tags = const [],
  }) =>
      JournalEntry(
        id: map['id'] as int?,
        title: map['title'] as String,
        content: (map['content'] as String?) ?? '',
        mood: Mood.fromId((map['mood'] as String?) ?? 'neutral'),
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        entryDate: AppDate.parseDayKey(map['entry_date'] as String),
        createdAt: map['created_at'] as int,
        updatedAt: map['updated_at'] as int,
        tags: tags,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'mood': mood.id,
        'is_favorite': isFavorite ? 1 : 0,
        'entry_date': AppDate.dayKey(entryDate),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  JournalEntry copyWith({
    int? id,
    String? title,
    String? content,
    Mood? mood,
    bool? isFavorite,
    DateTime? entryDate,
    int? createdAt,
    int? updatedAt,
    List<String>? tags,
  }) =>
      JournalEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        mood: mood ?? this.mood,
        isFavorite: isFavorite ?? this.isFavorite,
        entryDate: entryDate ?? this.entryDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        tags: tags ?? this.tags,
      );
}
