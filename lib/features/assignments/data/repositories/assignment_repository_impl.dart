import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/date_time_x.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/repositories/assignment_repository.dart';
import '../datasources/assignment_local_data_source.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  AssignmentRepositoryImpl({
    required AssignmentLocalDataSource localDataSource,
    required AppDatabase appDatabase,
    required NotificationService notificationService,
    required Uuid idGenerator,
  }) : _local = localDataSource,
       _database = appDatabase,
       _notifications = notificationService,
       _uuid = idGenerator;

  final AssignmentLocalDataSource _local;
  final AppDatabase _database;
  final NotificationService _notifications;
  final Uuid _uuid;

  @override
  Future<Result<List<Assignment>>> fetch({
    required String userId,
    required AssignmentFilter filter,
  }) => guard(() => _local.fetchForUser(userId, filter: filter));

  @override
  Future<Result<List<Assignment>>> fetchUpcoming({
    required String userId,
    int limit = 5,
  }) => guard(() => _local.fetchUpcoming(userId, limit: limit));

  @override
  Future<Result<AssignmentCounts>> counts(String userId) =>
      guard(() => _local.counts(userId));

  @override
  Future<Result<Assignment>> create({
    required String userId,
    required String title,
    required String details,
    required AssignmentCategory category,
    required AssignmentPriority priority,
    required DateTime dueAt,
    required int reminderMinutes,
    String? courseId,
  }) => guard(() async {
    final cleanTitle = Validators.sanitize(title, maxLength: 120);
    final error = Validators.requiredText(cleanTitle, field: 'Title');
    if (error != null) throw ValidationException(error);

    final now = DateTime.now();
    final assignment = Assignment(
      id: _uuid.v4(),
      userId: userId,
      courseId: courseId,
      title: cleanTitle,
      details: Validators.sanitizeMultiline(details),
      category: category,
      priority: priority,
      status: AssignmentStatus.pending,
      dueAt: dueAt,
      reminderMinutes: reminderMinutes,
      notificationId: await _database.reserveNotificationId(),
      createdAt: now,
      updatedAt: now,
    );

    await _local.insert(assignment);
    await _syncReminder(assignment);

    // Re-read so the joined course code and colour are populated.
    return await _local.findById(assignment.id, userId) ?? assignment;
  });

  @override
  Future<Result<Assignment>> update(Assignment assignment) => guard(() async {
    final cleanTitle = Validators.sanitize(assignment.title, maxLength: 120);
    final error = Validators.requiredText(cleanTitle, field: 'Title');
    if (error != null) throw ValidationException(error);

    final updated = assignment.copyWith(
      title: cleanTitle,
      details: Validators.sanitizeMultiline(assignment.details),
      updatedAt: DateTime.now(),
    );

    final rows = await _local.update(updated);
    if (rows == 0) {
      throw const NotFoundException('That item no longer exists.');
    }

    await _syncReminder(updated);
    return await _local.findById(updated.id, updated.userId) ?? updated;
  });

  @override
  Future<Result<Assignment>> setStatus(
    Assignment assignment,
    AssignmentStatus status,
  ) => guard(() async {
    final isCompleting = status == AssignmentStatus.completed;
    final updated = assignment.copyWith(
      status: status,
      completedAt: isCompleting ? DateTime.now() : null,
      clearCompletedAt: !isCompleting,
      updatedAt: DateTime.now(),
    );

    final rows = await _local.update(updated);
    if (rows == 0) {
      throw const NotFoundException('That item no longer exists.');
    }

    await _syncReminder(updated);
    return await _local.findById(updated.id, updated.userId) ?? updated;
  });

  @override
  Future<Result<void>> delete(Assignment assignment) => guard(() async {
    await _notifications.cancel(assignment.notificationId);
    await _local.delete(assignment.id, assignment.userId);
  });

  @override
  Future<Result<int>> rescheduleAllReminders(String userId) => guard(() async {
    final pending = await _local.fetchPendingWithReminders(userId);
    var scheduled = 0;
    for (final assignment in pending) {
      if (await _syncReminder(assignment)) scheduled++;
    }
    return scheduled;
  });

  /// Keeps the OS alarm in step with the record: completed or past-due items
  /// have their reminder withdrawn instead of firing pointlessly.
  Future<bool> _syncReminder(Assignment assignment) async {
    if (assignment.isCompleted) {
      await _notifications.cancel(assignment.notificationId);
      return false;
    }

    final courseLabel = assignment.courseCode == null
        ? ''
        : '${assignment.courseCode} • ';
    return _notifications.scheduleOneOff(
      notificationId: assignment.notificationId,
      channel: ReminderChannel.deadlines,
      title: '${assignment.category.label} due ${AppDateFormat.relativeToNow(assignment.dueAt)}',
      body: '$courseLabel${assignment.title}',
      eventAt: assignment.dueAt,
      minutesBefore: assignment.reminderMinutes,
    );
  }
}
