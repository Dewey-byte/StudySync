import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/features/schedule/domain/entities/class_session.dart';
import 'package:studysync/features/schedule/domain/entities/course.dart';

ClassSession buildSession({
  int dayOfWeek = DateTime.wednesday,
  int startMinute = 9 * 60,
  int endMinute = 10 * 60 + 30,
}) {
  final now = DateTime(2026, 1, 1);
  return ClassSession(
    id: 'session-1',
    courseId: 'course-1',
    dayOfWeek: dayOfWeek,
    startMinute: startMinute,
    endMinute: endMinute,
    room: 'Room 214',
    reminderMinutes: 15,
    notificationId: 1001,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ClassSession', () {
    test('duration is the gap between start and end', () {
      expect(buildSession().duration, const Duration(hours: 1, minutes: 30));
    });

    test('nextOccurrence lands on the right weekday and time', () {
      // 2026-08-16 is a Sunday; the next Wednesday is 2026-08-19.
      final next = buildSession().nextOccurrence(
        from: DateTime(2026, 8, 16, 12),
      );

      expect(next, DateTime(2026, 8, 19, 9));
      expect(next.weekday, DateTime.wednesday);
    });

    test('nextOccurrence skips today once the class has already started', () {
      final session = buildSession();
      final next = session.nextOccurrence(
        from: DateTime(2026, 8, 19, 11),
      );

      expect(next, DateTime(2026, 8, 26, 9));
    });

    test('nextOccurrence still returns today when the class is later on', () {
      final next = buildSession().nextOccurrence(
        from: DateTime(2026, 8, 19, 7),
      );

      expect(next, DateTime(2026, 8, 19, 9));
    });

    test('timeRange renders both ends of the slot', () {
      expect(buildSession().timeRange, '9:00 AM – 10:30 AM');
    });
  });

  group('ScheduledClass', () {
    final course = Course(
      id: 'course-1',
      userId: 'user-1',
      code: 'IT 126',
      title: 'Mobile Development',
      instructor: 'Prof. Santos',
      colorValue: Course.palette.first,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('isHappeningAt is true only inside the slot on the right day', () {
      final scheduled = ScheduledClass(
        course: course,
        session: buildSession(),
      );

      // Wednesday 09:30 is inside 09:00-10:30.
      expect(scheduled.isHappeningAt(DateTime(2026, 8, 19, 9, 30)), isTrue);
      // The end minute is exclusive.
      expect(scheduled.isHappeningAt(DateTime(2026, 8, 19, 10, 30)), isFalse);
      expect(scheduled.isHappeningAt(DateTime(2026, 8, 19, 8, 59)), isFalse);
      // Same time, wrong day.
      expect(scheduled.isHappeningAt(DateTime(2026, 8, 20, 9, 30)), isFalse);
    });

    test('displayName prefers the course code when present', () {
      expect(course.displayName, 'IT 126 — Mobile Development');
      expect(
        course.copyWith(code: '').displayName,
        'Mobile Development',
      );
    });
  });
}
