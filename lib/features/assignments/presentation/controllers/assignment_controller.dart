import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_revision.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/assignment_local_data_source.dart';
import '../../data/repositories/assignment_repository_impl.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/repositories/assignment_repository.dart';

final assignmentRepositoryProvider = Provider<AssignmentRepository>(
  (ref) => AssignmentRepositoryImpl(
    localDataSource: AssignmentLocalDataSource(ref.watch(appDatabaseProvider)),
    appDatabase: ref.watch(appDatabaseProvider),
    notificationService: ref.watch(notificationServiceProvider),
    idGenerator: ref.watch(uuidProvider),
  ),
);

/// Which slice of the tracker the list screen is showing.
final assignmentFilterProvider = StateProvider<AssignmentFilter>(
  (ref) => AssignmentFilter.upcoming,
);

final assignmentListProvider =
    AsyncNotifierProvider<AssignmentListController, List<Assignment>>(
      AssignmentListController.new,
    );

/// Loads the assignment list and applies every mutation to it.
///
/// Mutation methods return a nullable error message; a null result means the
/// write succeeded and the list has been refreshed.
class AssignmentListController extends AsyncNotifier<List<Assignment>> {
  AssignmentRepository get _repository => ref.read(assignmentRepositoryProvider);

  @override
  Future<List<Assignment>> build() async {
    // Re-runs whenever the filter, the signed-in user, or the data changes.
    final user = ref.watch(currentUserProvider);
    final filter = ref.watch(assignmentFilterProvider);
    ref.watch(dataRevisionProvider);

    if (user == null) return const <Assignment>[];

    final result = await _repository.fetch(userId: user.id, filter: filter);
    return result.fold(
      onSuccess: (items) => items,
      onFailure: (error) => throw error,
    );
  }

  Future<String?> create({
    required String title,
    required String details,
    required AssignmentCategory category,
    required AssignmentPriority priority,
    required DateTime dueAt,
    required int reminderMinutes,
    String? courseId,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return 'You are not signed in.';

    final result = await _repository.create(
      userId: user.id,
      title: title,
      details: details,
      category: category,
      priority: priority,
      dueAt: dueAt,
      reminderMinutes: reminderMinutes,
      courseId: courseId,
    );
    return _finish(result.errorOrNull?.message);
  }

  /// Named `saveEdits` rather than `update` because [AsyncNotifier] already
  /// defines an `update` method with a different meaning.
  Future<String?> saveEdits(Assignment assignment) async {
    final result = await _repository.update(assignment);
    return _finish(result.errorOrNull?.message);
  }

  /// Flips between completed and not started, which is what the list checkbox
  /// does.
  Future<String?> toggleCompleted(Assignment assignment) async {
    final result = await _repository.setStatus(
      assignment,
      assignment.isCompleted
          ? AssignmentStatus.pending
          : AssignmentStatus.completed,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> setStatus(
    Assignment assignment,
    AssignmentStatus status,
  ) async {
    final result = await _repository.setStatus(assignment, status);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> delete(Assignment assignment) async {
    final result = await _repository.delete(assignment);
    return _finish(result.errorOrNull?.message);
  }

  String? _finish(String? error) {
    if (error == null) ref.bumpDataRevision();
    return error;
  }
}
