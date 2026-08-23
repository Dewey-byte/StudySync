import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_revision.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/schedule_local_data_source.dart';
import '../../data/repositories/schedule_repository_impl.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(
    localDataSource: ScheduleLocalDataSource(ref.watch(appDatabaseProvider)),
    appDatabase: ref.watch(appDatabaseProvider),
    notificationService: ref.watch(notificationServiceProvider),
    idGenerator: ref.watch(uuidProvider),
  ),
);

/// The weekday currently selected in the timetable, 1 = Monday.
final selectedWeekdayProvider = StateProvider<int>(
  (ref) => DateTime.now().weekday,
);

/// The student's courses, used by the timetable and the assignment form.
final courseListProvider = FutureProvider<List<Course>>((ref) async {
  final user = ref.watch(currentUserProvider);
  ref.watch(dataRevisionProvider);
  if (user == null) return const <Course>[];

  final result = await ref
      .watch(scheduleRepositoryProvider)
      .fetchCourses(user.id);
  return result.fold(
    onSuccess: (courses) => courses,
    onFailure: (error) => throw error,
  );
});

/// Every class meeting in the week, grouped by weekday for the timetable.
final weeklyScheduleProvider =
    FutureProvider<Map<int, List<ScheduledClass>>>((ref) async {
      final user = ref.watch(currentUserProvider);
      ref.watch(dataRevisionProvider);
      if (user == null) return const <int, List<ScheduledClass>>{};

      final result = await ref
          .watch(scheduleRepositoryProvider)
          .fetchWeek(user.id);
      return result.fold(
        onSuccess: (classes) {
          final byDay = <int, List<ScheduledClass>>{
            for (var day = DateTime.monday; day <= DateTime.sunday; day++)
              day: <ScheduledClass>[],
          };
          for (final scheduled in classes) {
            byDay[scheduled.session.dayOfWeek]?.add(scheduled);
          }
          return byDay;
        },
        onFailure: (error) => throw error,
      );
    });

final scheduleControllerProvider = Provider<ScheduleController>(
  ScheduleController.new,
);

/// Write operations for courses and class meetings.
class ScheduleController {
  ScheduleController(this._ref);

  final Ref _ref;

  ScheduleRepository get _repository => _ref.read(scheduleRepositoryProvider);

  String? get _userId => _ref.read(currentUserProvider)?.id;

  Future<String?> createCourse({
    required String code,
    required String title,
    required String instructor,
    required int colorValue,
  }) async {
    final userId = _userId;
    if (userId == null) return 'You are not signed in.';

    final result = await _repository.createCourse(
      userId: userId,
      code: code,
      title: title,
      instructor: instructor,
      colorValue: colorValue,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> updateCourse(Course course) async {
    final result = await _repository.updateCourse(course);
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> deleteCourse(Course course) async {
    final result = await _repository.deleteCourse(course);
    return _finish(result.errorOrNull?.message);
  }

  /// Existing classes that overlap the proposed slot, so the form can warn
  /// before saving rather than silently double-booking.
  Future<List<ScheduledClass>> findConflicts({
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    String? excludeSessionId,
  }) async {
    final userId = _userId;
    if (userId == null) return const <ScheduledClass>[];

    final result = await _repository.findConflicts(
      userId: userId,
      dayOfWeek: dayOfWeek,
      startMinute: startMinute,
      endMinute: endMinute,
      excludeSessionId: excludeSessionId,
    );
    return result.valueOrNull ?? const <ScheduledClass>[];
  }

  Future<String?> addSession({
    required String courseId,
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    required String room,
    required int reminderMinutes,
  }) async {
    final userId = _userId;
    if (userId == null) return 'You are not signed in.';

    final result = await _repository.addSession(
      userId: userId,
      courseId: courseId,
      dayOfWeek: dayOfWeek,
      startMinute: startMinute,
      endMinute: endMinute,
      room: room,
      reminderMinutes: reminderMinutes,
    );
    return _finish(result.errorOrNull?.message);
  }

  Future<String?> deleteSession(ClassSession session) async {
    final userId = _userId;
    if (userId == null) return 'You are not signed in.';

    final result = await _repository.deleteSession(
      userId: userId,
      session: session,
    );
    return _finish(result.errorOrNull?.message);
  }

  String? _finish(String? error) {
    if (error == null) _ref.bumpDataRevision();
    return error;
  }
}
