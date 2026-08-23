import 'package:flutter/foundation.dart';

/// A project or organisation group the student collaborates in.
@immutable
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.joinCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;

  /// Short human-readable code shared with classmates so they can add the same
  /// group on their own device.
  final String joinCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyGroup copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
  }) => StudyGroup(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    description: description ?? this.description,
    joinCode: joinCode,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyGroup && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

enum GroupRole {
  owner('owner', 'Owner'),
  member('member', 'Member');

  const GroupRole(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static GroupRole fromStorage(String? value) => GroupRole.values.firstWhere(
    (role) => role.storageValue == value,
    orElse: () => GroupRole.member,
  );
}

@immutable
class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final String displayName;
  final GroupRole role;
  final DateTime joinedAt;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupMember && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum GroupTaskStatus {
  todo('todo', 'To do'),
  inProgress('in_progress', 'In progress'),
  done('done', 'Done');

  const GroupTaskStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static GroupTaskStatus fromStorage(String? value) =>
      GroupTaskStatus.values.firstWhere(
        (status) => status.storageValue == value,
        orElse: () => GroupTaskStatus.todo,
      );
}

@immutable
class GroupTask {
  const GroupTask({
    required this.id,
    required this.groupId,
    required this.title,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assigneeId,
    this.assigneeName,
    this.dueAt,
  });

  final String id;
  final String groupId;
  final String title;
  final String details;
  final GroupTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assigneeId;

  /// Denormalised from the joined member row for list rendering.
  final String? assigneeName;
  final DateTime? dueAt;

  bool get isDone => status == GroupTaskStatus.done;

  bool get isOverdue {
    final due = dueAt;
    return !isDone && due != null && due.isBefore(DateTime.now());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupTask && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

@immutable
class GroupAnnouncement {
  const GroupAnnouncement({
    required this.id,
    required this.groupId,
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String authorName;
  final String message;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupAnnouncement && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class GroupMeeting {
  const GroupMeeting({
    required this.id,
    required this.groupId,
    required this.title,
    required this.location,
    required this.scheduledAt,
    required this.reminderMinutes,
    required this.notificationId,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String title;
  final String location;
  final DateTime scheduledAt;
  final int reminderMinutes;
  final int notificationId;
  final DateTime createdAt;

  bool get isPast => scheduledAt.isBefore(DateTime.now());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupMeeting && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Group plus the counts shown on the list screen, assembled in one query
/// instead of fetching every child collection per row.
@immutable
class GroupOverview {
  const GroupOverview({
    required this.group,
    required this.memberCount,
    required this.openTaskCount,
    this.nextMeetingAt,
  });

  final StudyGroup group;
  final int memberCount;
  final int openTaskCount;
  final DateTime? nextMeetingAt;
}

/// Everything shown on a single group's detail screen.
@immutable
class GroupDetail {
  const GroupDetail({
    required this.group,
    required this.members,
    required this.tasks,
    required this.announcements,
    required this.meetings,
  });

  final StudyGroup group;
  final List<GroupMember> members;
  final List<GroupTask> tasks;
  final List<GroupAnnouncement> announcements;
  final List<GroupMeeting> meetings;

  List<GroupTask> get openTasks =>
      tasks.where((task) => !task.isDone).toList(growable: false);

  double get completionRatio {
    if (tasks.isEmpty) return 0;
    return tasks.where((task) => task.isDone).length / tasks.length;
  }

  GroupMeeting? get nextMeeting {
    final upcoming = meetings.where((meeting) => !meeting.isPast).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
