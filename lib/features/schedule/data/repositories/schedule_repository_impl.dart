import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/date_time_x.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_local_data_source.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({
    required ScheduleLocalDataSource localDataSource,
    required AppDatabase appDatabase,
    required NotificationService notificationService,
    required Uuid idGenerator,
  }) : _local = localDataSource,
       _database = appDatabase,
       _notifications = notificationService,
       _uuid = idGenerator;

  final ScheduleLocalDataSource _local;
  final AppDatabase _database;
  final NotificationService _notifications;
  final Uuid _uuid;

  @override
  Future<Result<List<Course>>> fetchCourses(String userId) =>
      guard(() => _local.fetchCourses(userId));

  @override
  Future<Result<Course>> createCourse({
    required String userId,
    required String code,
    required String title,
    required String instructor,
    required int colorValue,
  }) => guard(() async {
    final cleanTitle = Validators.sanitize(title, maxLength: 100);
    final error = Validators.requiredText(cleanTitle, field: 'Course title');
    if (error != null) throw ValidationException(error);

    final now = DateTime.now();
    final course = Course(
      id: _uuid.v4(),
      userId: userId,
      code: Validators.sanitize(code, maxLength: 20).toUpperCase(),
      title: cleanTitle,
      instructor: Validators.sanitize(instructor, maxLength: 80),
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await _local.insertCourse(course);
    return course;
  });

  @override
  Future<Result<Course>> updateCourse(Course course) => guard(() async {
    final cleanTitle = Validators.sanitize(course.title, maxLength: 100);
    final error = Validators.requiredText(cleanTitle, field: 'Course title');
    if (error != null) throw ValidationException(error);

    final updated = course.copyWith(
      title: cleanTitle,
      code: Validators.sanitize(course.code, maxLength: 20).toUpperCase(),
      instructor: Validators.sanitize(course.instructor, maxLength: 80),
      updatedAt: DateTime.now(),
    );

    if (await _local.updateCourse(updated) == 0) {
      throw const NotFoundException('That course no longer exists.');
    }

    // The course name appears in the reminder text, so refresh them.
    await _rescheduleCourse(updated);
    return updated;
  });

  @override
  Future<Result<void>> deleteCourse(Course course) => guard(() async {
    for (final session in await _local.fetchSessionsForCourse(course.id)) {
      await _notifications.cancel(session.notificationId);
    }
    await _local.deleteCourse(course.id, course.userId);
  });

  @override
  Future<Result<List<ScheduledClass>>> fetchWeek(String userId) =>
      guard(() => _local.fetchWeek(userId));

  @override
  Future<Result<List<ScheduledClass>>> fetchForDay({
    required String userId,
    required int dayOfWeek,
  }) => guard(() => _local.fetchForDay(userId, dayOfWeek));

  @override
  Future<Result<List<ScheduledClass>>> fetchRemainingToday(String userId) =>
      guard(() async {
        final now = DateTime.now();
        final today = await _local.fetchForDay(userId, now.weekday);
        return today
            .where((scheduled) => scheduled.session.endMinute > now.minuteOfDay)
            .toList(growable: false);
      });

  @override
  Future<Result<List<ScheduledClass>>> findConflicts({
    required String userId,
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    String? excludeSessionId,
  }) => guard(
    () => _local.findConflicts(
      userId: userId,
      dayOfWeek: dayOfWeek,
      startMinute: startMinute,
      endMinute: endMinute,
      excludeSessionId: excludeSessionId,
    ),
  );

  @override
  Future<Result<ClassSession>> addSession({
    required String userId,
    required String courseId,
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    required String room,
    required int reminderMinutes,
  }) => guard(() async {
    final course = await _local.findCourse(courseId, userId);
    if (course == null) {
      throw const NotFoundException('That course no longer exists.');
    }
    _validateSlot(dayOfWeek: dayOfWeek, start: startMinute, end: endMinute);

    final now = DateTime.now();
    final session = ClassSession(
      id: _uuid.v4(),
      courseId: courseId,
      dayOfWeek: dayOfWeek,
      startMinute: startMinute,
      endMinute: endMinute,
      room: Validators.sanitize(room, maxLength: 40),
      reminderMinutes: reminderMinutes,
      notificationId: await _database.reserveNotificationId(),
      createdAt: now,
      updatedAt: now,
    );

    await _local.insertSession(session);
    await _scheduleSessionReminder(course, session);
    return session;
  });

  @override
  Future<Result<ClassSession>> updateSession(ClassSession session) =>
      guard(() async {
        _validateSlot(
          dayOfWeek: session.dayOfWeek,
          start: session.startMinute,
          end: session.endMinute,
        );

        final updated = session.copyWith(
          room: Validators.sanitize(session.room, maxLength: 40),
          updatedAt: DateTime.now(),
        );
        if (await _local.updateSession(updated) == 0) {
          throw const NotFoundException('That class no longer exists.');
        }
        return updated;
      });

  @override
  Future<Result<void>> deleteSession({
    required String userId,
    required ClassSession session,
  }) => guard(() async {
    await _notifications.cancel(session.notificationId);
    await _local.deleteSession(session.id, userId);
  });

  @override
  Future<Result<int>> rescheduleAllReminders(String userId) => guard(() async {
    final week = await _local.fetchWeek(userId);
    for (final scheduled in week) {
      await _scheduleSessionReminder(scheduled.course, scheduled.session);
    }
    return week.length;
  });

  Future<void> _rescheduleCourse(Course course) async {
    for (final session in await _local.fetchSessionsForCourse(course.id)) {
      await _scheduleSessionReminder(course, session);
    }
  }

  Future<void> _scheduleSessionReminder(
    Course course,
    ClassSession session,
  ) async {
    final where = session.room.isEmpty ? '' : ' • ${session.room}';
    await _notifications.scheduleWeekly(
      notificationId: session.notificationId,
      channel: ReminderChannel.classes,
      title: '${course.code.isEmpty ? course.title : course.code} starts soon',
      body:
          '${AppDateFormat.minuteOfDay(session.startMinute)}'
          '$where',
      dayOfWeek: session.dayOfWeek,
      startMinuteOfDay: session.startMinute,
      minutesBefore: session.reminderMinutes,
    );
  }

  static void _validateSlot({
    required int dayOfWeek,
    required int start,
    required int end,
  }) {
    if (dayOfWeek < DateTime.monday || dayOfWeek > DateTime.sunday) {
      throw const ValidationException('Choose a valid day of the week.');
    }
    if (end <= start) {
      throw const ValidationException('End time must be after the start time.');
    }
  }
}
