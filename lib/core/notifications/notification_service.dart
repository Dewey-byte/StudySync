import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Logical grouping of reminders, exposed to the user as separate Android
/// channels so they can mute meetings without losing deadline alerts.
enum ReminderChannel {
  deadlines(
    'studysync_deadlines',
    'Assignment deadlines',
    'Reminders before assignments, quizzes and exams are due',
  ),
  classes(
    'studysync_classes',
    'Class schedule',
    'Reminders before each scheduled class starts',
  ),
  groups(
    'studysync_groups',
    'Group collaboration',
    'Group meeting reminders and announcements',
  );

  const ReminderChannel(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

/// Schedules the local notifications that make StudySync useful offline.
///
/// Everything is handed to the OS scheduler up front, so reminders still fire
/// when the app has been swiped away or the device has no connectivity.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _localTimeZoneName()));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Deferred until the user has seen why the app needs them.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    _initialised = true;
  }

  /// Asks for notification permission. Safe to call more than once; the OS
  /// only shows the prompt the first time.
  Future<bool> requestPermissions() async {
    await init();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      // Needed on Android 12+ for minute-accurate deadline reminders.
      await android.requestExactAlarmsPermission();
      return granted;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Schedules a one-off reminder [minutesBefore] ahead of [eventAt].
  ///
  /// Returns false when that moment is already in the past, which keeps the
  /// caller from assuming a reminder exists.
  Future<bool> scheduleOneOff({
    required int notificationId,
    required ReminderChannel channel,
    required String title,
    required String body,
    required DateTime eventAt,
    required int minutesBefore,
  }) async {
    await init();
    final fireAt = tz.TZDateTime.from(
      eventAt.subtract(Duration(minutes: minutesBefore)),
      tz.local,
    );
    if (!fireAt.isAfter(tz.TZDateTime.now(tz.local))) {
      await cancel(notificationId);
      return false;
    }

    await _zonedSchedule(
      notificationId: notificationId,
      channel: channel,
      title: title,
      body: body,
      fireAt: fireAt,
    );
    return true;
  }

  /// Schedules a reminder that repeats every week on [dayOfWeek] (1 = Monday).
  Future<void> scheduleWeekly({
    required int notificationId,
    required ReminderChannel channel,
    required String title,
    required String body,
    required int dayOfWeek,
    required int startMinuteOfDay,
    required int minutesBefore,
  }) async {
    await init();
    await _zonedSchedule(
      notificationId: notificationId,
      channel: channel,
      title: title,
      body: body,
      fireAt: _nextWeekdayOccurrence(
        dayOfWeek: dayOfWeek,
        minuteOfDay: startMinuteOfDay - minutesBefore,
      ),
      matchComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _zonedSchedule({
    required int notificationId,
    required ReminderChannel channel,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    DateTimeComponents? matchComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: fireAt,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.title,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      // A missing exact-alarm permission must not block saving the record.
      debugPrint('Could not schedule notification $notificationId: $e');
    }
  }

  Future<void> cancel(int notificationId) async {
    await init();
    await _plugin.cancel(id: notificationId);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Next occurrence of [minuteOfDay] on [dayOfWeek], in local time.
  ///
  /// [minuteOfDay] may be negative when a reminder lead time pushes it into the
  /// previous day, so the arithmetic is done in [Duration] rather than on the
  /// hour and minute fields.
  static tz.TZDateTime _nextWeekdayOccurrence({
    required int dayOfWeek,
    required int minuteOfDay,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: minuteOfDay));

    while (candidate.weekday != dayOfWeek || !candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static Future<String> _localTimeZoneName() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}
