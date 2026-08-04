import '../../core/utils/date_utils.dart';

/// One day's log for a habit. `count` for a good habit means repetitions done;
/// for a bad habit it means how many times the behavior happened (0 = clean day).
class HabitLog {
  const HabitLog({
    this.id,
    required this.habitId,
    required this.date,
    required this.count,
    required this.note,
    required this.createdAt,
  });

  final int? id;
  final int habitId;
  final DateTime date;
  final int count;
  final String note;
  final int createdAt;

  factory HabitLog.fromMap(Map<String, Object?> map) => HabitLog(
        id: map['id'] as int?,
        habitId: map['habit_id'] as int,
        date: AppDate.parseDayKey(map['date'] as String),
        count: map['count'] as int? ?? 0,
        note: (map['note'] as String?) ?? '',
        createdAt: map['created_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'habit_id': habitId,
        'date': AppDate.dayKey(date),
        'count': count,
        'note': note,
        'created_at': createdAt,
      };
}
