import '../../domain/entities/study_group.dart';

abstract final class StudyGroupMapper {
  static StudyGroup fromRow(Map<String, Object?> row) => StudyGroup(
    id: row['id']! as String,
    ownerId: row['owner_id']! as String,
    name: row['name']! as String,
    description: row['description'] as String? ?? '',
    joinCode: row['join_code']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
  );

  static Map<String, Object?> toColumns(StudyGroup group) => <String, Object?>{
    'id': group.id,
    'owner_id': group.ownerId,
    'name': group.name,
    'description': group.description,
    'join_code': group.joinCode,
    'created_at': group.createdAt.millisecondsSinceEpoch,
    'updated_at': group.updatedAt.millisecondsSinceEpoch,
  };
}

abstract final class GroupMemberMapper {
  static GroupMember fromRow(Map<String, Object?> row) => GroupMember(
    id: row['id']! as String,
    groupId: row['group_id']! as String,
    displayName: row['display_name']! as String,
    role: GroupRole.fromStorage(row['role'] as String?),
    joinedAt: DateTime.fromMillisecondsSinceEpoch(row['joined_at']! as int),
  );

  static Map<String, Object?> toColumns(GroupMember member) =>
      <String, Object?>{
        'id': member.id,
        'group_id': member.groupId,
        'display_name': member.displayName,
        'role': member.role.storageValue,
        'joined_at': member.joinedAt.millisecondsSinceEpoch,
      };
}

abstract final class GroupTaskMapper {
  static GroupTask fromRow(Map<String, Object?> row) => GroupTask(
    id: row['id']! as String,
    groupId: row['group_id']! as String,
    assigneeId: row['assignee_id'] as String?,
    assigneeName: row['assignee_name'] as String?,
    title: row['title']! as String,
    details: row['details'] as String? ?? '',
    status: GroupTaskStatus.fromStorage(row['status'] as String?),
    dueAt: row['due_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['due_at']! as int)
        : null,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
  );

  static Map<String, Object?> toColumns(GroupTask task) => <String, Object?>{
    'id': task.id,
    'group_id': task.groupId,
    'assignee_id': task.assigneeId,
    'title': task.title,
    'details': task.details,
    'status': task.status.storageValue,
    'due_at': task.dueAt?.millisecondsSinceEpoch,
    'created_at': task.createdAt.millisecondsSinceEpoch,
    'updated_at': task.updatedAt.millisecondsSinceEpoch,
  };
}

abstract final class GroupAnnouncementMapper {
  static GroupAnnouncement fromRow(Map<String, Object?> row) =>
      GroupAnnouncement(
        id: row['id']! as String,
        groupId: row['group_id']! as String,
        authorName: row['author_name']! as String,
        message: row['message']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
      );

  static Map<String, Object?> toColumns(GroupAnnouncement announcement) =>
      <String, Object?>{
        'id': announcement.id,
        'group_id': announcement.groupId,
        'author_name': announcement.authorName,
        'message': announcement.message,
        'created_at': announcement.createdAt.millisecondsSinceEpoch,
      };
}

abstract final class GroupMeetingMapper {
  static GroupMeeting fromRow(Map<String, Object?> row) => GroupMeeting(
    id: row['id']! as String,
    groupId: row['group_id']! as String,
    title: row['title']! as String,
    location: row['location'] as String? ?? '',
    scheduledAt: DateTime.fromMillisecondsSinceEpoch(
      row['scheduled_at']! as int,
    ),
    reminderMinutes: row['reminder_minutes'] as int? ?? 30,
    notificationId: row['notification_id']! as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
  );

  static Map<String, Object?> toColumns(GroupMeeting meeting) =>
      <String, Object?>{
        'id': meeting.id,
        'group_id': meeting.groupId,
        'title': meeting.title,
        'location': meeting.location,
        'scheduled_at': meeting.scheduledAt.millisecondsSinceEpoch,
        'reminder_minutes': meeting.reminderMinutes,
        'notification_id': meeting.notificationId,
        'created_at': meeting.createdAt.millisecondsSinceEpoch,
      };
}
