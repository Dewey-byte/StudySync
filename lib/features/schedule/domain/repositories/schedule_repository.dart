import '../../../../core/result/result.dart';
import '../entities/class_session.dart';
import '../entities/course.dart';

abstract interface class ScheduleRepository {
  Future<Result<List<Course>>> fetchCourses(String userId);

  Future<Result<Course>> createCourse({
    required String userId,
    required String code,
    required String title,
    required String instructor,
    required int colorValue,
  });

  Future<Result<Course>> updateCourse(Course course);

  /// Removes the course together with its meetings and their reminders.
  Future<Result<void>> deleteCourse(Course course);

  Future<Result<List<ScheduledClass>>> fetchWeek(String userId);

  Future<Result<List<ScheduledClass>>> fetchForDay({
    required String userId,
    required int dayOfWeek,
  });

  /// Classes still to start today, soonest first.
  Future<Result<List<ScheduledClass>>> fetchRemainingToday(String userId);

  Future<Result<List<ScheduledClass>>> findConflicts({
    required String userId,
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    String? excludeSessionId,
  });

  Future<Result<ClassSession>> addSession({
    required String userId,
    required String courseId,
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    required String room,
    required int reminderMinutes,
  });

  Future<Result<ClassSession>> updateSession(ClassSession session);

  Future<Result<void>> deleteSession({
    required String userId,
    required ClassSession session,
  });

  Future<Result<int>> rescheduleAllReminders(String userId);
}
