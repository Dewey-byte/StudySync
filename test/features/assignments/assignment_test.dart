import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/features/assignments/domain/entities/assignment.dart';

Assignment buildAssignment({
  required DateTime dueAt,
  AssignmentStatus status = AssignmentStatus.pending,
}) {
  final created = DateTime(2026);
  return Assignment(
    id: 'assignment-1',
    userId: 'user-1',
    title: 'Research paper draft',
    details: '',
    category: AssignmentCategory.project,
    priority: AssignmentPriority.high,
    status: status,
    dueAt: dueAt,
    reminderMinutes: 1440,
    notificationId: 1002,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  group('Assignment status helpers', () {
    test('is overdue once the due date has passed', () {
      final assignment = buildAssignment(
        dueAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(assignment.isOverdue, isTrue);
      expect(assignment.isDueSoon, isFalse);
    });

    test('a completed item is never overdue', () {
      final assignment = buildAssignment(
        dueAt: DateTime.now().subtract(const Duration(days: 5)),
        status: AssignmentStatus.completed,
      );

      expect(assignment.isCompleted, isTrue);
      expect(assignment.isOverdue, isFalse);
    });

    test('is due soon within the next 48 hours', () {
      expect(
        buildAssignment(
          dueAt: DateTime.now().add(const Duration(hours: 10)),
        ).isDueSoon,
        isTrue,
      );
      expect(
        buildAssignment(
          dueAt: DateTime.now().add(const Duration(days: 5)),
        ).isDueSoon,
        isFalse,
      );
    });
  });

  group('Assignment.copyWith', () {
    test('clearCourse detaches the course and its denormalised fields', () {
      final withCourse = Assignment(
        id: 'a',
        userId: 'u',
        title: 'Title',
        details: '',
        category: AssignmentCategory.quiz,
        priority: AssignmentPriority.low,
        status: AssignmentStatus.pending,
        dueAt: DateTime(2026, 9),
        reminderMinutes: 60,
        notificationId: 5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        courseId: 'course-1',
        courseCode: 'IT 126',
        courseColorValue: 0xFF4F46E5,
      );

      final detached = withCourse.copyWith(clearCourse: true);

      expect(detached.courseId, isNull);
      expect(detached.courseCode, isNull);
      expect(detached.courseColorValue, isNull);
    });

    test('clearCompletedAt removes the completion timestamp', () {
      final completed = buildAssignment(
        dueAt: DateTime(2026, 9),
        status: AssignmentStatus.completed,
      ).copyWith(completedAt: DateTime(2026, 9, 2));

      expect(completed.completedAt, isNotNull);
      expect(
        completed.copyWith(clearCompletedAt: true).completedAt,
        isNull,
      );
    });

    test('preserves identity fields that must never change', () {
      final original = buildAssignment(dueAt: DateTime(2026, 9));
      final edited = original.copyWith(title: 'New title');

      expect(edited.id, original.id);
      expect(edited.userId, original.userId);
      expect(edited.notificationId, original.notificationId);
      expect(edited.createdAt, original.createdAt);
    });
  });

  group('Enum storage values', () {
    test('round-trip through their stored representation', () {
      for (final category in AssignmentCategory.values) {
        expect(
          AssignmentCategory.fromStorage(category.storageValue),
          category,
        );
      }
      for (final priority in AssignmentPriority.values) {
        expect(AssignmentPriority.fromStorage(priority.storageValue), priority);
      }
      for (final status in AssignmentStatus.values) {
        expect(AssignmentStatus.fromStorage(status.storageValue), status);
      }
    });

    test('fall back to a safe default for unknown or null values', () {
      expect(
        AssignmentCategory.fromStorage('something-else'),
        AssignmentCategory.assignment,
      );
      expect(
        AssignmentPriority.fromStorage(null),
        AssignmentPriority.medium,
      );
      expect(AssignmentStatus.fromStorage(''), AssignmentStatus.pending);
    });
  });
}
