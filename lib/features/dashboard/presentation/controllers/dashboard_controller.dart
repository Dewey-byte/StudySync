import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/data_revision.dart';
import '../../../../core/result/result.dart';
import '../../../assignments/domain/entities/assignment.dart';
import '../../../assignments/domain/repositories/assignment_repository.dart';
import '../../../assignments/presentation/controllers/assignment_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../groups/domain/entities/study_group.dart';
import '../../../groups/presentation/controllers/group_controller.dart';
import '../../../schedule/domain/entities/class_session.dart';
import '../../../schedule/presentation/controllers/schedule_controller.dart';

/// Everything the home screen shows, gathered in one place so the widget tree
/// only waits on a single future.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.counts,
    required this.upcomingAssignments,
    required this.remainingClassesToday,
    required this.upcomingMeetings,
  });

  final AssignmentCounts counts;
  final List<Assignment> upcomingAssignments;
  final List<ScheduledClass> remainingClassesToday;
  final List<GroupMeeting> upcomingMeetings;

  bool get isEmpty =>
      upcomingAssignments.isEmpty &&
      remainingClassesToday.isEmpty &&
      upcomingMeetings.isEmpty &&
      counts.overdue == 0;
}

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final user = ref.watch(currentUserProvider);
  ref.watch(dataRevisionProvider);

  if (user == null) {
    return const DashboardSummary(
      counts: (dueToday: 0, overdue: 0, completed: 0),
      upcomingAssignments: <Assignment>[],
      remainingClassesToday: <ScheduledClass>[],
      upcomingMeetings: <GroupMeeting>[],
    );
  }

  final assignments = ref.watch(assignmentRepositoryProvider);
  final schedule = ref.watch(scheduleRepositoryProvider);
  final groups = ref.watch(groupRepositoryProvider);

  // Independent queries, so run them concurrently rather than in sequence.
  final results = await Future.wait(<Future<Object>>[
    assignments.counts(user.id),
    assignments.fetchUpcoming(userId: user.id, limit: 4),
    schedule.fetchRemainingToday(user.id),
    groups.fetchUpcomingMeetings(userId: user.id, limit: 3),
  ]);

  return DashboardSummary(
    counts:
        (results[0] as Result<AssignmentCounts>).valueOrNull ??
        (dueToday: 0, overdue: 0, completed: 0),
    upcomingAssignments:
        (results[1] as Result<List<Assignment>>).valueOrNull ??
        const <Assignment>[],
    remainingClassesToday:
        (results[2] as Result<List<ScheduledClass>>).valueOrNull ??
        const <ScheduledClass>[],
    upcomingMeetings:
        (results[3] as Result<List<GroupMeeting>>).valueOrNull ??
        const <GroupMeeting>[],
  );
});
