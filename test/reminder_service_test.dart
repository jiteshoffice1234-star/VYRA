import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/application/habits/habit_providers.dart';
import 'package:vyra/application/providers/app_providers.dart';
import 'package:vyra/core/database/app_database.dart';
import 'package:vyra/data/repositories/habit_repository.dart';
import 'package:vyra/data/services/reminder_service.dart';
import 'package:vyra/domain/models/habit.dart';

Habit _habit({
  int id = 1,
  bool archived = false,
  bool reminderEnabled = false,
  String? reminderTime,
}) =>
    Habit(
      id: id,
      name: 'Habit $id',
      description: '',
      type: HabitType.good,
      color: 0xFF10B981,
      iconIndex: 0,
      targetPerDay: 1,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
      archived: archived,
      createdAt: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    );

/// Records what the platform was asked to do, so resync behavior can be
/// asserted without platform channels (flutter test has none).
class _RecordingScheduler implements ReminderScheduler {
  final resynced = <Habit>[];

  @override
  Future<void> initialize({void Function(String payload)? onTap}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDaily({
    required int habitId,
    required String habitName,
    required String time,
  }) async {}

  @override
  Future<void> cancel(int habitId) async {}

  @override
  Future<void> resyncAll(List<Habit> habits) async {
    resynced.addAll(habits);
  }

  @override
  Future<String?> launchPayload() async => null;
}

void main() {
  group('nextReminderOccurrence', () {
    test('returns today when the time is still ahead', () {
      final now = DateTime(2026, 8, 14, 10, 0);
      expect(nextReminderOccurrence(now, 18, 30), DateTime(2026, 8, 14, 18, 30));
    });

    test('returns tomorrow when the time has already passed', () {
      final now = DateTime(2026, 8, 14, 20, 0);
      expect(nextReminderOccurrence(now, 7, 15), DateTime(2026, 8, 15, 7, 15));
    });

    test('returns tomorrow when the time is exactly now', () {
      final now = DateTime(2026, 8, 14, 7, 15, 30);
      expect(
        nextReminderOccurrence(now, 7, 15),
        DateTime(2026, 8, 15, 7, 15),
      );
    });

    test('wraps across a year boundary', () {
      final newYearsEve = DateTime(2026, 12, 31, 23, 0);
      expect(
        nextReminderOccurrence(newYearsEve, 6, 0),
        DateTime(2027, 1, 1, 6, 0),
      );
    });

    test('handles midnight times', () {
      final now = DateTime(2026, 8, 14, 0, 5);
      expect(
        nextReminderOccurrence(now, 0, 0),
        DateTime(2026, 8, 15, 0, 0),
      );
    });

    test('keeps seconds of the base time for the same-day comparison', () {
      // 10:00:45 means the 10:00 reminder has already passed -> next day.
      final now = DateTime(2026, 8, 14, 10, 0, 45);
      expect(
        nextReminderOccurrence(now, 10, 0),
        DateTime(2026, 8, 15, 10, 0),
      );
    });
  });

  group('shouldScheduleReminder', () {
    test('enabled habit with a time is scheduled', () {
      expect(
        shouldScheduleReminder(
          _habit(reminderEnabled: true, reminderTime: '07:30'),
        ),
        isTrue,
      );
    });

    test('missing time or disabled flag means no reminder', () {
      expect(shouldScheduleReminder(_habit(reminderEnabled: true)), isFalse);
      expect(
        shouldScheduleReminder(
          _habit(reminderEnabled: false, reminderTime: '07:30'),
        ),
        isFalse,
      );
    });

    test('archived habits never get reminders, even if enabled', () {
      expect(
        shouldScheduleReminder(
          _habit(archived: true, reminderEnabled: true, reminderTime: '07:30'),
        ),
        isFalse,
      );
    });
  });

  group('HabitsNotifier.resyncReminders', () {
    test('hands every stored habit (incl. archived) to the scheduler',
        () async {
      final db = await AppDatabase.openInMemory();
      final scheduler = _RecordingScheduler();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);

      final repo = HabitRepository(db.db);
      await repo.insert(
        _habit(id: 1, reminderEnabled: true, reminderTime: '07:30'),
      );
      await repo.insert(_habit(id: 2));
      await repo.insert(
        _habit(id: 3, archived: true, reminderEnabled: true, reminderTime: '09:00'),
      );

      final notifier = container.read(habitsProvider.notifier);
      await notifier.resyncReminders();

      // The full set (active + archived) reaches the scheduler, which owns
      // the enabled/archived policy.
      expect(scheduler.resynced.map((h) => h.id).toSet(), {1, 2, 3});
    });
  });
}
