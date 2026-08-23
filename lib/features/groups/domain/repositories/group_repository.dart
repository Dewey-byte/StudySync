import '../../../../core/result/result.dart';
import '../entities/study_group.dart';

abstract interface class GroupRepository {
  Future<Result<List<GroupOverview>>> fetchOverviews(String userId);

  Future<Result<GroupDetail>> fetchDetail({
    required String userId,
    required String groupId,
  });

  Future<Result<StudyGroup>> createGroup({
    required String userId,
    required String ownerDisplayName,
    required String name,
    required String description,
  });

  Future<Result<StudyGroup>> updateGroup(StudyGroup group);

  Future<Result<void>> deleteGroup(StudyGroup group);

  Future<Result<void>> addMember({
    required String groupId,
    required String displayName,
  });

  Future<Result<void>> removeMember({
    required String groupId,
    required String memberId,
  });

  Future<Result<void>> addTask({
    required String groupId,
    required String title,
    required String details,
    String? assigneeId,
    DateTime? dueAt,
  });

  Future<Result<void>> updateTaskStatus({
    required GroupTask task,
    required GroupTaskStatus status,
  });

  Future<Result<void>> deleteTask(GroupTask task);

  Future<Result<void>> postAnnouncement({
    required String groupId,
    required String authorName,
    required String message,
  });

  Future<Result<void>> deleteAnnouncement(GroupAnnouncement announcement);

  Future<Result<void>> scheduleMeeting({
    required String groupId,
    required String groupName,
    required String title,
    required String location,
    required DateTime scheduledAt,
    required int reminderMinutes,
  });

  Future<Result<void>> cancelMeeting(GroupMeeting meeting);

  /// Meetings across all of the user's groups, for the dashboard.
  Future<Result<List<GroupMeeting>>> fetchUpcomingMeetings({
    required String userId,
    int limit,
  });
}
