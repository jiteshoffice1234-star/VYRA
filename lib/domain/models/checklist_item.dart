/// One line of a checklist note.
class ChecklistItem {
  const ChecklistItem({
    this.id,
    this.noteId,
    required this.text,
    required this.isChecked,
    required this.position,
  });

  final int? id;
  final int? noteId;
  final String text;
  final bool isChecked;
  final int position;

  factory ChecklistItem.fromMap(Map<String, Object?> map) => ChecklistItem(
        id: map['id'] as int?,
        noteId: map['note_id'] as int?,
        text: map['text'] as String,
        isChecked: (map['is_checked'] as int? ?? 0) == 1,
        position: map['position'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'note_id': noteId,
        'text': text,
        'is_checked': isChecked ? 1 : 0,
        'position': position,
      };

  ChecklistItem copyWith({int? id, String? text, bool? isChecked, int? position}) =>
      ChecklistItem(
        id: id ?? this.id,
        noteId: noteId,
        text: text ?? this.text,
        isChecked: isChecked ?? this.isChecked,
        position: position ?? this.position,
      );
}
