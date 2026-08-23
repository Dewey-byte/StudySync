import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/study_group.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/group_local_data_source.dart';

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({
    required GroupLocalDataSource localDataSource,
    required AppDatabase appDatabase,
    required NotificationService notificationService,
    required Uuid idGenerator,
  }) : _local = localDataSource,
       _database = appDatabase,
       _notifications = notificationService,
       _uuid = idGenerator;

  /// Excludes characters that are easy to misread when a code is copied off
  /// someone else's screen (0/O, 1/I/L).
  static const String _joinCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int _joinCodeLength = 6;

  static final Random _random = Random.secure();

  final GroupLocalDataSource _local;
  final AppDatabase _database;
  final NotificationService _notifications;
  final Uuid _uuid;

  @override
  Future<Result<List<GroupOverview>>> fetchOverviews(String userId) =>
      guard(() => _local.fetchOverviews(userId));

  @override
  Future<Result<GroupDetail>> fetchDetail({
    required String userId,
    required String groupId,
  }) => guard(() async {
    final detail = await _local.fetchDetail(groupId, userId);
    if (detail == null) {
      throw const NotFoundException('That group is no longer available.');
    }
    return detail;
  });

  @override
  Future<Result<StudyGroup>> createGroup({
    required String userId,
    required String ownerDisplayName,
    required String name,
    required String description,
  }) => guard(() async {
    final cleanName = Validators.sanitize(name, maxLength: 80);
    final error = Validators.requiredText(cleanName, field: 'Group name');
    if (error != null) throw ValidationException(error);

    final now = DateTime.now();
    final group = StudyGroup(
      id: _uuid.v4(),
      ownerId: userId,
      name: cleanName,
      description: Validators.sanitizeMultiline(description, maxLength: 500),
      joinCode: await _generateJoinCode(),
      createdAt: now,
      updatedAt: now,
    );

    await _local.insertGroupWithOwner(
      group,
      GroupMember(
        id: _uuid.v4(),
        groupId: group.id,
        displayName: Validators.sanitize(ownerDisplayName, maxLength: 80),
        role: GroupRole.owner,
        joinedAt: now,
      ),
    );
    return group;
  });

  @override
  Future<Result<StudyGroup>> updateGroup(StudyGroup group) => guard(() async {
    final cleanName = Validators.sanitize(group.name, maxLength: 80);
    final error = Validators.requiredText(cleanName, field: 'Group name');
    if (error != null) throw ValidationException(error);

    final updated = group.copyWith(
      name: cleanName,
      description: Validators.sanitizeMultiline(
        group.description,
        maxLength: 500,
      ),
      updatedAt: DateTime.now(),
    );
    if (await _local.updateGroup(updated) == 0) {
      throw const NotFoundException('That group is no longer available.');
    }
    return updated;
  });

  @override
  Future<Result<void>> deleteGroup(StudyGroup group) => guard(() async {
    for (final meeting in await _local.fetchMeetings(group.id)) {
      await _notifications.cancel(meeting.notificationId);
    }
    await _local.deleteGroup(group.id, group.ownerId);
  });

  @override
  Future<Result<void>> addMember({
    required String groupId,
    required String displayName,
  }) => guard(() async {
    final cleanName = Validators.sanitize(displayName, maxLength: 80);
    final error = Validators.requiredText(cleanName, field: 'Member name');
    if (error != null) throw ValidationException(error);

    await _local.insertMember(
      GroupMember(
        id: _uuid.v4(),
        groupId: groupId,
        displayName: cleanName,
        role: GroupRole.member,
        joinedAt: DateTime.now(),
      ),
    );
  });

  @override
  Future<Result<void>> removeMember({
    required String groupId,
    required String memberId,
  }) => guard(() async {
    if (await _local.deleteMember(memberId, groupId) == 0) {
      throw const ValidationException('The group owner cannot be removed.');
    }
  });

  @override
  Future<Result<void>> addTask({
    required String groupId,
    required String title,
    required String details,
    String? assigneeId,
    DateTime? dueAt,
  }) => guard(() async {
    final cleanTitle = Validators.sanitize(title, maxLength: 120);
    final error = Validators.requiredText(cleanTitle, field: 'Task title');
    if (error != null) throw ValidationException(error);

    final now = DateTime.now();
    await _local.insertTask(
      GroupTask(
        id: _uuid.v4(),
        groupId: groupId,
        assigneeId: assigneeId,
        title: cleanTitle,
        details: Validators.sanitizeMultiline(details, maxLength: 500),
        status: GroupTaskStatus.todo,
        dueAt: dueAt,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  @override
  Future<Result<void>> updateTaskStatus({
    required GroupTask task,
    required GroupTaskStatus status,
  }) => guard(() async {
    final updated = GroupTask(
      id: task.id,
      groupId: task.groupId,
      assigneeId: task.assigneeId,
      title: task.title,
      details: task.details,
      status: status,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );
    if (await _local.updateTask(updated) == 0) {
      throw const NotFoundException('That task no longer exists.');
    }
  });

  @override
  Future<Result<void>> deleteTask(GroupTask task) =>
      guard(() => _local.deleteTask(task.id, task.groupId));

  @override
  Future<Result<void>> postAnnouncement({
    required String groupId,
    required String authorName,
    required String message,
  }) => guard(() async {
    final cleanMessage = Validators.sanitizeMultiline(message, maxLength: 1000);
    final error = Validators.requiredText(cleanMessage, field: 'Announcement');
    if (error != null) throw ValidationException(error);

    await _local.insertAnnouncement(
      GroupAnnouncement(
        id: _uuid.v4(),
        groupId: groupId,
        authorName: Validators.sanitize(authorName, maxLength: 80),
        message: cleanMessage,
        createdAt: DateTime.now(),
      ),
    );
  });

  @override
  Future<Result<void>> deleteAnnouncement(GroupAnnouncement announcement) =>
      guard(
        () => _local.deleteAnnouncement(announcement.id, announcement.groupId),
      );

  @override
  Future<Result<void>> scheduleMeeting({
    required String groupId,
    required String groupName,
    required String title,
    required String location,
    required DateTime scheduledAt,
    required int reminderMinutes,
  }) => guard(() async {
    final cleanTitle = Validators.sanitize(title, maxLength: 120);
    final error = Validators.requiredText(cleanTitle, field: 'Meeting title');
    if (error != null) throw ValidationException(error);

    final cleanLocation = Validators.sanitize(location, maxLength: 120);
    final meeting = GroupMeeting(
      id: _uuid.v4(),
      groupId: groupId,
      title: cleanTitle,
      location: cleanLocation,
      scheduledAt: scheduledAt,
      reminderMinutes: reminderMinutes,
      notificationId: await _database.reserveNotificationId(),
      createdAt: DateTime.now(),
    );

    await _local.insertMeeting(meeting);
    await _notifications.scheduleOneOff(
      notificationId: meeting.notificationId,
      channel: ReminderChannel.groups,
      title: '$groupName meeting',
      body: cleanLocation.isEmpty
          ? cleanTitle
          : '$cleanTitle • $cleanLocation',
      eventAt: scheduledAt,
      minutesBefore: reminderMinutes,
    );
  });

  @override
  Future<Result<void>> cancelMeeting(GroupMeeting meeting) => guard(() async {
    await _notifications.cancel(meeting.notificationId);
    await _local.deleteMeeting(meeting.id, meeting.groupId);
  });

  @override
  Future<Result<List<GroupMeeting>>> fetchUpcomingMeetings({
    required String userId,
    int limit = 5,
  }) => guard(() => _local.fetchUpcomingMeetings(userId, limit: limit));

  /// Retries until the generated code is unused, so two groups can never share
  /// one and confuse the people joining.
  Future<String> _generateJoinCode() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = List<String>.generate(
        _joinCodeLength,
        (_) => _joinCodeAlphabet[_random.nextInt(_joinCodeAlphabet.length)],
      ).join();
      if (!await _local.joinCodeExists(code)) return code;
    }
    throw const StorageException('Could not generate a unique group code.');
  }
}
