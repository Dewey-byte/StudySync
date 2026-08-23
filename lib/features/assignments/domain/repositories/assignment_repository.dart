import '../../../../core/result/result.dart';
import '../entities/assignment.dart';

/// Summary counts shown on the dashboard.
typedef AssignmentCounts = ({int dueToday, int overdue, int completed});

abstract interface class AssignmentRepository {
  Future<Result<List<Assignment>>> fetch({
    required String userId,
    required AssignmentFilter filter,
  });

  Future<Result<List<Assignment>>> fetchUpcoming({
    required String userId,
    int limit,
  });

  Future<Result<AssignmentCounts>> counts(String userId);

  Future<Result<Assignment>> create({
    required String userId,
    required String title,
    required String details,
    required AssignmentCategory category,
    required AssignmentPriority priority,
    required DateTime dueAt,
    required int reminderMinutes,
    String? courseId,
  });

  Future<Result<Assignment>> update(Assignment assignment);

  Future<Result<Assignment>> setStatus(
    Assignment assignment,
    AssignmentStatus status,
  );

  Future<Result<void>> delete(Assignment assignment);

  /// Re-registers every future reminder with the OS. Used after the user grants
  /// notification permission, or when reminders may have been dropped.
  Future<Result<int>> rescheduleAllReminders(String userId);
}
