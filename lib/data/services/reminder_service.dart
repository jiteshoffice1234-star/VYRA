import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/logger.dart';
import '../../domain/models/habit.dart';

/// Set when the user taps a habit-reminder notification. The app shell
/// consumes it once the router is attached (see VyraApp) and opens the
/// habit's detail screen. Payloads are consumed exactly once.
final ValueNotifier<String?> pendingReminderRoute = ValueNotifier<String?>(null);

/// The app's single scheduler instance, shared by startup (which calls
/// [ReminderScheduler.initialize]) and the provider used by feature code —
/// plugin state (initialization, timezone) must live on one instance.
final ReminderScheduler appReminderScheduler = LocalReminderScheduler();

/// Notification ids live in their own range so they can never collide with
/// any future app-level notifications.
int _reminderNotificationId(int habitId) => 1000 + habitId;

/// The next wall-clock occurrence of [hour]:[minute] strictly after [now],
/// in [now]'s timezone. Pure so it can be unit-tested without a device.
DateTime nextReminderOccurrence(DateTime now, int hour, int minute) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = DateTime(now.year, now.month, now.day + 1, hour, minute);
  }
  return next;
}

/// Whether [habit] should have a daily reminder scheduled: enabled, has a
/// stored time, and not archived (archived habits must not nag). Pure so the
/// resync-after-restore policy is unit-testable without a device.
bool shouldScheduleReminder(Habit habit) =>
    !habit.archived &&
    habit.reminderEnabled &&
    habit.reminderTime != null;

/// Abstraction over the notification platform so the scheduling logic can be
/// exercised without platform channels (flutter test has none).
abstract class ReminderScheduler {
  /// Prepares the plugin (timezone database, per-platform settings) and
  /// registers [onTap] for notification taps. Idempotent; safe to call once
  /// at startup. Failures are logged, never thrown.
  Future<void> initialize({void Function(String payload)? onTap});

  /// Asks the OS for permission to post notifications. Android 13+ shows a
  /// system prompt; older Android is already granted at install time.
  Future<bool> requestPermission();

  /// Schedules (or replaces) the daily reminder for [habitId] at [time]
  /// ("HH:mm" in device-local time). Best-effort: failures are logged.
  Future<void> scheduleDaily({
    required int habitId,
    required String habitName,
    required String time,
  });

  /// Removes any scheduled reminder for [habitId].
  Future<void> cancel(int habitId);

  /// Brings the OS notification state in line with [habits]: every habit
  /// with a reminder enabled (and not archived) is (re)scheduled, every
  /// other scheduled reminder in the app's id range is cancelled — including
  /// orphans whose habit id no longer exists. Used after a backup restore,
  /// which rewrites the database without going through the per-habit save
  /// path. Best-effort: failures are logged, never thrown.
  Future<void> resyncAll(List<Habit> habits);

  /// The notification payload that launched the app, if the app was launched
  /// by tapping a reminder (cold start). Null otherwise.
  Future<String?> launchPayload();
}

/// flutter_local_notifications-backed implementation.
///
/// Android: daily repeating alarms are inexact (no exact-alarm permission
/// needed); the plugin's boot receiver re-registers them after a reboot.
/// Windows: repeating notifications are not supported, so reminders fire
/// once. iOS/macOS: foreground presentation is handled by the plugin.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'habit_reminders';
  static const String _channelName = 'Habit reminders';
  static const String _channelDescription =
      'Daily reminders for your habits';

  bool _initialized = false;

  @override
  Future<void> initialize({void Function(String payload)? onTap}) async {
    if (_initialized || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e, st) {
        // Fall back to UTC rather than failing startup; reminders then fire
        // at UTC time-of-day, which is only wrong for non-UTC zones.
        AppLogger.error('Failed to resolve device timezone', e, st);
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'VYRA',
          appUserModelId: 'com.vyra.vyra',
          guid: '85f1f2f0-1e3c-4a6b-9f3a-0d2b7e4c8a11',
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: onTap == null
            ? null
            : (response) => onTap(response.payload ?? ''),
      );
      _initialized = true;
    } catch (e, st) {
      // Reminders are best-effort: never take the app down with them.
      AppLogger.error('Failed to initialize notifications', e, st);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        return await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      // No runtime permission model on Windows/Linux: nothing to deny, so
      // treat as granted rather than nagging about a system settings fix.
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to request notification permission', e, st);
      return false;
    }
  }

  @override
  Future<void> scheduleDaily({
    required int habitId,
    required String habitName,
    required String time,
  }) async {
    if (kIsWeb || !_initialized) return;
    final parts = time.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    try {
      final next = nextReminderOccurrence(DateTime.now(), hour, minute);
      final scheduled = tz.TZDateTime.from(next, tz.local);
      await _plugin.zonedSchedule(
        id: _reminderNotificationId(habitId),
        title: 'Habit reminder',
        body: 'Time for $habitName',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$habitId',
      );
    } catch (e, st) {
      AppLogger.error('Failed to schedule habit reminder', e, st);
    }
  }

  @override
  Future<void> cancel(int habitId) async {
    if (kIsWeb || !_initialized) return;
    try {
      await _plugin.cancel(id: _reminderNotificationId(habitId));
    } catch (e, st) {
      AppLogger.error('Failed to cancel habit reminder', e, st);
    }
  }

  @override
  Future<void> resyncAll(List<Habit> habits) async {
    if (kIsWeb || !_initialized) return;
    final desired = <int>{};
    for (final habit in habits) {
      final id = habit.id;
      if (id == null) continue;
      if (shouldScheduleReminder(habit)) {
        desired.add(id);
        await scheduleDaily(
          habitId: id,
          habitName: habit.name,
          time: habit.reminderTime!,
        );
      } else {
        // Disabled / archived habits must not keep an old notification
        // (their id may now belong to a different habit after a restore).
        await cancel(id);
      }
    }
    // A restore replaced the whole dataset: prune notifications for habit
    // ids that no longer exist at all (the app's own id range only).
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final id = request.id;
        if (id < _reminderNotificationId(0)) continue;
        if (!desired.contains(id - _reminderNotificationId(0))) {
          await _plugin.cancel(id: id);
        }
      }
    } catch (e, st) {
      AppLogger.error('Failed to prune stale reminders after restore', e, st);
    }
  }

  @override
  Future<String?> launchPayload() async {
    if (kIsWeb || !_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
    } catch (e, st) {
      AppLogger.error('Failed to read launch notification', e, st);
    }
    return null;
  }
}
