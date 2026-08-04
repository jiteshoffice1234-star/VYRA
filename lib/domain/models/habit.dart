/// Whether a habit is something to do (good) or to avoid (bad).
enum HabitType {
  good('good'),
  bad('bad');

  const HabitType(this.id);

  final String id;

  static HabitType fromId(String id) =>
      values.firstWhere((t) => t.id == id, orElse: () => HabitType.good);
}

/// A tracked habit. `color` and `iconIndex` drive its visual identity.
class Habit {
  const Habit({
    this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.color,
    required this.iconIndex,
    this.categoryId,
    this.categoryName,
    required this.targetPerDay,
    this.reminderTime,
    required this.reminderEnabled,
    required this.createdAt,
    this.archived = false,
  });

  final int? id;
  final String name;
  final String description;
  final HabitType type;
  final int color; // ARGB
  final int iconIndex;
  final int? categoryId;
  final String? categoryName; // joined from categories
  final int targetPerDay;
  final String? reminderTime; // "HH:mm", reminder is a v1 placeholder
  final bool reminderEnabled;
  final bool archived;
  final int createdAt;

  factory Habit.fromMap(Map<String, Object?> map) => Habit(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: (map['description'] as String?) ?? '',
        type: HabitType.fromId((map['type'] as String?) ?? 'good'),
        color: map['color'] as int,
        iconIndex: map['icon_index'] as int? ?? 0,
        categoryId: map['category_id'] as int?,
        categoryName: map['category_name'] as String?,
        targetPerDay: map['target_per_day'] as int? ?? 1,
        reminderTime: map['reminder_time'] as String?,
        reminderEnabled: (map['reminder_enabled'] as int? ?? 0) == 1,
        archived: (map['archived'] as int? ?? 0) == 1,
        createdAt: map['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.id,
        'color': color,
        'icon_index': iconIndex,
        'category_id': categoryId,
        'target_per_day': targetPerDay,
        'reminder_time': reminderTime,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'archived': archived ? 1 : 0,
        'created_at': createdAt,
      };

  Habit copyWith({
    int? id,
    String? name,
    String? description,
    HabitType? type,
    int? color,
    int? iconIndex,
    int? categoryId,
    String? categoryName,
    int? targetPerDay,
    String? reminderTime,
    bool? reminderEnabled,
    bool? archived,
    int? createdAt,
  }) =>
      Habit(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        type: type ?? this.type,
        color: color ?? this.color,
        iconIndex: iconIndex ?? this.iconIndex,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        targetPerDay: targetPerDay ?? this.targetPerDay,
        reminderTime: reminderTime ?? this.reminderTime,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        archived: archived ?? this.archived,
        createdAt: createdAt ?? this.createdAt,
      );
}
