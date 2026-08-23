import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_revision.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/group_local_data_source.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/study_group.dart';
import '../../domain/repositories/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepositoryImpl(
    localDataSource: GroupLocalDataSource(ref.watch(appDatabaseProvider)),
    appDatabase: ref.watch(appDatabaseProvider),
    notificationService: ref.watch(notificationServiceProvider),
    idGenerator: ref.watch(uuidProvider),
  ),
);

final groupListProvider = FutureProvider<List<GroupOverview>>((ref) async {
  final user = ref.watch(currentUserProvider);
  ref.watch(dataRevisionProvider);
  if (user == null) return const <GroupOverview>[];

  final result = await ref
      .watch(groupRepositoryProvider)
      .fetchOverviews(user.id);
  return result.fold(
    onSuccess: (groups) => groups,
    onFailure: (error) => throw error,
  );
});

/// Full contents of one group, keyed by group id.
final groupDetailProvider = FutureProvider.family<GroupDetail, String>((
  ref,
  groupId,
) async {
  final user = ref.watch(currentUserProvider);
  ref.watch(dataRevisionProvider);
  if (user == null) throw StateError('Not signed in');

  final result = await ref
      .watch(groupRepositoryProvider)
      .fetchDetail(userId: user.id, groupId: groupId);
  return result.fold(
    onSuccess: (detail) => detail,
    onFailure: (error) => throw error,
  );
});

final groupControllerProvider = Provider<GroupController>(GroupController.new);

/// Write operations for groups, members, tasks, announcements and meetings.
class GroupController {
  GroupController(this._ref);

  final Ref _ref;

  GroupRepository get _repository => _ref.read(groupRepositoryProvider);

  Future<String?> createGroup({
    required String name,
    required String description,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return 'You are not signed in.';

    final result = await _repository.createGroup(
      userId: user.id,
      ownerDisplayName: user.fullName,
      name: name,
      description: description,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> updateGroup(StudyGroup group) async {
    final result = await _repository.updateGroup(group);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> deleteGroup(StudyGroup group) async {
    final result = await _repository.deleteGroup(group);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> addMember({
    required String groupId,
    required String displayName,
  }) async {
    final result = await _repository.addMember(
      groupId: groupId,
      displayName: displayName,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    final result = await _repository.removeMember(
      groupId: groupId,
      memberId: memberId,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> addTask({
    required String groupId,
    required String title,
    required String details,
    String? assigneeId,
    DateTime? dueAt,
  }) async {
    final result = await _repository.addTask(
      groupId: groupId,
      title: title,
      details: details,
      assigneeId: assigneeId,
      dueAt: dueAt,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> cycleTaskStatus(GroupTask task) async {
    final next = switch (task.status) {
      GroupTaskStatus.todo => GroupTaskStatus.inProgress,
      GroupTaskStatus.inProgress => GroupTaskStatus.done,
      GroupTaskStatus.done => GroupTaskStatus.todo,
    };
    final result = await _repository.updateTaskStatus(task: task, status: next);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> deleteTask(GroupTask task) async {
    final result = await _repository.deleteTask(task);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> postAnnouncement({
    required String groupId,
    required String message,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return 'You are not signed in.';

    final result = await _repository.postAnnouncement(
      groupId: groupId,
      authorName: user.fullName,
      message: message,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> deleteAnnouncement(GroupAnnouncement announcement) async {
    final result = await _repository.deleteAnnouncement(announcement);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> scheduleMeeting({
    required String groupId,
    required String groupName,
    required String title,
    required String location,
    required DateTime scheduledAt,
    required int reminderMinutes,
  }) async {
    final result = await _repository.scheduleMeeting(
      groupId: groupId,
      groupName: groupName,
      title: title,
      location: location,
      scheduledAt: scheduledAt,
      reminderMinutes: reminderMinutes,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> cancelMeeting(GroupMeeting meeting) async {
    final result = await _repository.cancelMeeting(meeting);
    return _finish(result.errorOrNull?.message);
  }

  String? _finish(String? error) {
    if (error == null) _ref.bumpDataRevision();
    return error;
  }
}
