import '../../domain/entities/assignment.dart';

/// Translates between the `assignments` table and the [Assignment] entity.
///
/// Kept out of the entity so the domain layer has no knowledge of column names
/// or millisecond timestamps.
abstract final class AssignmentMapper {
  static Assignment fromRow(Map<String, Object?> row) => Assignment(
    id: row['id']! as String,
    userId: row['user_id']! as String,
    courseId: row['course_id'] as String?,
    courseCode: row['course_code'] as String?,
    courseColorValue: row['course_color'] as int?,
    title: row['title']! as String,
    details: row['details'] as String? ?? '',
    category: AssignmentCategory.fromStorage(row['category'] as String?),
    priority: AssignmentPriority.fromStorage(row['priority'] as String?),
    status: AssignmentStatus.fromStorage(row['status'] as String?),
    dueAt: DateTime.fromMillisecondsSinceEpoch(row['due_at']! as int),
    reminderMinutes: row['reminder_minutes'] as int? ?? 1440,
    notificationId: row['notification_id']! as int,
    completedAt: _nullableDate(row['completed_at']),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
  );

  static Map<String, Object?> toColumns(Assignment assignment) =>
      <String, Object?>{
        'id': assignment.id,
        'user_id': assignment.userId,
        'course_id': assignment.courseId,
        'title': assignment.title,
        'details': assignment.details,
        'category': assignment.category.storageValue,
        'priority': assignment.priority.storageValue,
        'status': assignment.status.storageValue,
        'due_at': assignment.dueAt.millisecondsSinceEpoch,
        'reminder_minutes': assignment.reminderMinutes,
        'notification_id': assignment.notificationId,
        'completed_at': assignment.completedAt?.millisecondsSinceEpoch,
        'created_at': assignment.createdAt.millisecondsSinceEpoch,
        'updated_at': assignment.updatedAt.millisecondsSinceEpoch,
      };

  static DateTime? _nullableDate(Object? value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(value)
      : null;
}
