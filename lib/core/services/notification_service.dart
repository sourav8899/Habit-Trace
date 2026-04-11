import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/habits/models/habit.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Optional callback — set this in main.dart to handle notification taps
  static void Function(String habitId)? onNotificationTap;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // payload format: 'habit:{habitId}'
        final payload = response.payload;
        if (payload != null && payload.startsWith('habit:')) {
          final habitId = payload.substring('habit:'.length);
          onNotificationTap?.call(habitId);
        }
      },
    );

    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    await init();

    var granted = true;

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final macImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();

    final androidGranted =
        await androidImplementation?.requestNotificationsPermission();
    final iosGranted = await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final macGranted = await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (androidGranted == false || iosGranted == false || macGranted == false) {
      granted = false;
    }

    return granted;
  }

  static Future<bool> requestReminderPermissions() async {
    await init();

    final notificationsGranted = await requestPermissions();
    if (!notificationsGranted) return false;

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // On Android 13+ USE_EXACT_ALARM is pre-granted via manifest — no dialog needed
    final canScheduleExact =
        await androidImplementation?.canScheduleExactNotifications();

    if (canScheduleExact == null || canScheduleExact) {
      return true; // already allowed
    }

    // Fallback: ask user to grant via settings (Android 12 only)
    final exactGranted =
        await androidImplementation?.requestExactAlarmsPermission();

    return exactGranted ?? false;
  }

  static Future<bool> canScheduleExactReminders() async {
    await init();

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final canScheduleExact =
        await androidImplementation?.canScheduleExactNotifications();

    return canScheduleExact ?? true;
  }

  /// Sync: cancel orphaned reminders, then schedule all active ones.
  static Future<void> syncHabitReminders(List<Habit> habits) async {
    await init();

    final activeIds =
        habits
            .where((h) => h.reminderHour != null && h.reminderMinute != null)
            .map((h) => _notificationIdFor(h.id))
            .toSet();

    // Cancel any pending notifications whose habit no longer has a reminder
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith('habit:') != true) continue;
      if (!activeIds.contains(request.id)) {
        await _plugin.cancel(request.id);
      }
    }

    // Schedule (or re-schedule) each habit that has a reminder
    for (final habit in habits) {
      await scheduleHabitReminder(habit);
    }
  }

  static Future<void> scheduleHabitReminder(Habit habit) async {
    await init();

    if (habit.reminderHour == null || habit.reminderMinute == null) {
      await cancelHabitReminder(habit.id);
      return;
    }

    final scheduledDate = _nextInstanceOfTime(
      habit.reminderHour!,
      habit.reminderMinute!,
    );

    final canScheduleExact = await canScheduleExactReminders();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily reminders to complete your habits',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        _notificationIdFor(habit.id),
        '${habit.iconEmoji} ${habit.name}',
        'Time to build your habit! Tap to mark it done.',
        scheduledDate,
        details,
        androidScheduleMode:
            canScheduleExact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'habit:${habit.id}',
      );
    } on PlatformException catch (error) {
      // Exact alarms not permitted — fall back to inexact
      if (error.code != 'exact_alarms_not_permitted') rethrow;

      await _plugin.zonedSchedule(
        _notificationIdFor(habit.id),
        '${habit.iconEmoji} ${habit.name}',
        'Time to build your habit! Tap to mark it done.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'habit:${habit.id}',
      );
    }
  }

  static Future<void> cancelHabitReminder(String habitId) async {
    await init();
    await _plugin.cancel(_notificationIdFor(habitId));
  }

  static int _notificationIdFor(String habitId) {
    return habitId.hashCode & 0x7fffffff;
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
