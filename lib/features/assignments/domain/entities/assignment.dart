import 'package:flutter/foundation.dart';

/// What kind of academic work an entry represents.
///
/// The stored value is pinned to a string so renaming an enum constant can
/// never silently reinterpret existing rows.
enum AssignmentCategory {
  assignment('assignment', 'Assignment'),
  project('project', 'Project'),
  quiz('quiz', 'Quiz'),
  exam('exam', 'Exam');

  const AssignmentCategory(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AssignmentCategory fromStorage(String? value) =>
      AssignmentCategory.values.firstWhere(
        (category) => category.storageValue == value,
        orElse: () => AssignmentCategory.assignment,
      );
}

enum AssignmentPriority {
  low('low', 'Low', 0),
  medium('medium', 'Medium', 1),
  high('high', 'High', 2);

  const AssignmentPriority(this.storageValue, this.label, this.weight);

  final String storageValue;
  final String label;

  /// Higher sorts first when two items share a due date.
  final int weight;

  static AssignmentPriority fromStorage(String? value) =>
      AssignmentPriority.values.firstWhere(
        (priority) => priority.storageValue == value,
        orElse: () => AssignmentPriority.medium,
      );
}

enum AssignmentStatus {
  pending('pending', 'Not started'),
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed');

  const AssignmentStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AssignmentStatus fromStorage(String? value) =>
      AssignmentStatus.values.firstWhere(
        (status) => status.storageValue == value,
        orElse: () => AssignmentStatus.pending,
      );
}

/// A single tracked piece of work, optionally attached to a course.
@immutable
class Assignment {
  const Assignment({
    required this.id,
    required this.userId,
    required this.title,
    required this.details,
    required this.category,
    required this.priority,
    required this.status,
    required this.dueAt,
    required this.reminderMinutes,
    required this.notificationId,
    required this.createdAt,
    required this.updatedAt,
    this.courseId,
    this.courseCode,
    this.courseColorValue,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String details;
  final AssignmentCategory category;
  final AssignmentPriority priority;
  final AssignmentStatus status;
  final DateTime dueAt;
  final int reminderMinutes;
  final int notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? courseId;

  /// Denormalised from the joined course row for list rendering.
  final String? courseCode;
  final int? courseColorValue;
  final DateTime? completedAt;

  bool get isCompleted => status == AssignmentStatus.completed;

  bool get isOverdue => !isCompleted && dueAt.isBefore(DateTime.now());

  /// Due within the next 48 hours and not finished yet.
  bool get isDueSoon {
    if (isCompleted || isOverdue) return false;
    return dueAt.difference(DateTime.now()) <= const Duration(hours: 48);
  }

  Assignment copyWith({
    String? title,
    String? details,
    AssignmentCategory? category,
    AssignmentPriority? priority,
    AssignmentStatus? status,
    DateTime? dueAt,
    int? reminderMinutes,
    DateTime? updatedAt,
    String? courseId,
    bool clearCourse = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => Assignment(
    id: id,
    userId: userId,
    title: title ?? this.title,
    details: details ?? this.details,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    dueAt: dueAt ?? this.dueAt,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    notificationId: notificationId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    courseId: clearCourse ? null : (courseId ?? this.courseId),
    courseCode: clearCourse ? null : courseCode,
    courseColorValue: clearCourse ? null : courseColorValue,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Assignment && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

/// Which slice of the tracker the user is looking at.
enum AssignmentFilter {
  upcoming('Upcoming'),
  overdue('Overdue'),
  completed('Completed'),
  all('All');

  const AssignmentFilter(this.label);

  final String label;
}
