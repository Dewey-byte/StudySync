import '../../domain/entities/class_session.dart';
import '../../domain/entities/course.dart';

abstract final class CourseMapper {
  static Course fromRow(Map<String, Object?> row, {String prefix = ''}) =>
      Course(
        id: row['${prefix}id']! as String,
        userId: row['${prefix}user_id']! as String,
        code: row['${prefix}code'] as String? ?? '',
        title: row['${prefix}title']! as String,
        instructor: row['${prefix}instructor'] as String? ?? '',
        colorValue: row['${prefix}color_value']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['${prefix}created_at']! as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['${prefix}updated_at']! as int,
        ),
      );

  static Map<String, Object?> toColumns(Course course) => <String, Object?>{
    'id': course.id,
    'user_id': course.userId,
    'code': course.code,
    'title': course.title,
    'instructor': course.instructor,
    'color_value': course.colorValue,
    'created_at': course.createdAt.millisecondsSinceEpoch,
    'updated_at': course.updatedAt.millisecondsSinceEpoch,
  };
}

abstract final class ClassSessionMapper {
  static ClassSession fromRow(Map<String, Object?> row, {String prefix = ''}) =>
      ClassSession(
        id: row['${prefix}id']! as String,
        courseId: row['${prefix}course_id']! as String,
        dayOfWeek: row['${prefix}day_of_week']! as int,
        startMinute: row['${prefix}start_minute']! as int,
        endMinute: row['${prefix}end_minute']! as int,
        room: row['${prefix}room'] as String? ?? '',
        reminderMinutes: row['${prefix}reminder_minutes'] as int? ?? 15,
        notificationId: row['${prefix}notification_id']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['${prefix}created_at']! as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['${prefix}updated_at']! as int,
        ),
      );

  static Map<String, Object?> toColumns(ClassSession session) =>
      <String, Object?>{
        'id': session.id,
        'course_id': session.courseId,
        'day_of_week': session.dayOfWeek,
        'start_minute': session.startMinute,
        'end_minute': session.endMinute,
        'room': session.room,
        'reminder_minutes': session.reminderMinutes,
        'notification_id': session.notificationId,
        'created_at': session.createdAt.millisecondsSinceEpoch,
        'updated_at': session.updatedAt.millisecondsSinceEpoch,
      };
}

/// Builds a [ScheduledClass] from a joined session + course row.
///
/// The query aliases course columns with a `c_` prefix so both tables can share
/// a result row without colliding on `id`, `created_at`, and friends.
abstract final class ScheduledClassMapper {
  static const String courseAliasPrefix = 'c_';

  static ScheduledClass fromJoinedRow(Map<String, Object?> row) =>
      ScheduledClass(
        course: CourseMapper.fromRow(row, prefix: courseAliasPrefix),
        session: ClassSessionMapper.fromRow(row),
      );
}
