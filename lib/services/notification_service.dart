import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // Unrecognised or unavailable timezone — fall back to UTC so the rest
      // of the notification system still works.
      debugPrint('NotificationService: timezone init failed ($e); using UTC');
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<void> requestPermission() async {
    if (!_initialized) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    bool fromTomorrow = false,
  }) async {
    if (!_initialized) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(time, fromTomorrow: fromTomorrow),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chiron_reminders',
          'Dagelijkse herinneringen',
          channelDescription:
              'Herinnering als je oefeningen nog niet gedaan zijn',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Reschedules the notification to fire from tomorrow at the given time.
  /// Schedules first so a failure leaves the existing notification intact,
  /// then cancels the old one (which is replaced by the new schedule when
  /// using the same ID on most platforms).
  Future<void> rescheduleFromTomorrow({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    // Scheduling with the same ID replaces the existing pending notification
    // atomically on Android/iOS — no explicit cancel needed.
    await scheduleDailyReminder(
      id: id,
      title: title,
      body: body,
      time: time,
      fromTomorrow: true,
    );
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id: id);
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time,
      {bool fromTomorrow = false}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (fromTomorrow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Uses abs() on the full hashCode (32-bit positive) to give a vastly larger
  // ID space than the previous % 100000, making hash collisions between
  // program IDs astronomically unlikely.
  static int notifId(String programId) => programId.hashCode.abs();

  /// Pure function: returns true when today's notification should be suppressed
  /// (i.e. `rescheduleFromTomorrow` should be called) after a workout.
  ///
  /// Suppress when notifications are enabled AND one of:
  ///   • the user completed their daily target (`completionsToday >= timesPerDay`)
  ///   • there are no exercises scheduled for today (`!hasExercisesToday`)
  ///
  /// Never suppress when notifications are disabled — there is nothing to cancel.
  static bool shouldSuppressNotificationToday({
    required bool notificationsEnabled,
    required bool hasExercisesToday,
    required int timesPerDay,
    required int completionsToday,
  }) {
    if (!notificationsEnabled) return false;
    if (!hasExercisesToday) return true;
    return completionsToday >= timesPerDay;
  }
}
