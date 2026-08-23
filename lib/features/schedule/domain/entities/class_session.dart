import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_x.dart';
import 'course.dart';

/// One weekly meeting of a course, e.g. "Mondays 09:00–10:30 in Room 214".
///
/// Times are stored as minutes past midnight rather than as [DateTime], because
/// the slot repeats every week and has no single calendar date.
@immutable
class ClassSession {
  const ClassSession({
    required this.id,
    required this.courseId,
    required this.dayOfWeek,
    required this.startMinute,
    required this.endMinute,
    required this.room,
    required this.reminderMinutes,
    required this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String courseId;

  /// 1 = Monday .. 7 = Sunday, matching [DateTime.weekday].
  final int dayOfWeek;
  final int startMinute;
  final int endMinute;
  final String room;
  final int reminderMinutes;
  final int notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration => Duration(minutes: endMinute - startMinute);

  String get timeRange =>
      '${AppDateFormat.minuteOfDay(startMinute)} – '
      '${AppDateFormat.minuteOfDay(endMinute)}';

  TimeOfDay get startTime => TimeOfDayX.fromMinuteOfDay(startMinute);

  TimeOfDay get endTime => TimeOfDayX.fromMinuteOfDay(endMinute);

  /// The next calendar date and time this class starts, at or after [from].
  DateTime nextOccurrence({DateTime? from}) {
    final reference = from ?? DateTime.now();
    var candidate = reference.startOfDay.add(Duration(minutes: startMinute));
    while (candidate.weekday != dayOfWeek || !candidate.isAfter(reference)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  ClassSession copyWith({
    int? dayOfWeek,
    int? startMinute,
    int? endMinute,
    String? room,
    int? reminderMinutes,
    DateTime? updatedAt,
  }) => ClassSession(
    id: id,
    courseId: courseId,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    room: room ?? this.room,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    notificationId: notificationId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSession && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}

/// A session joined with the course it belongs to, which is what every
/// timetable view actually needs.
@immutable
class ScheduledClass {
  const ScheduledClass({required this.course, required this.session});

  final Course course;
  final ClassSession session;

  String get id => session.id;

  /// Whether this class is happening right now, used to highlight the card on
  /// the "today" view.
  bool isHappeningAt(DateTime moment) =>
      moment.weekday == session.dayOfWeek &&
      moment.minuteOfDay >= session.startMinute &&
      moment.minuteOfDay < session.endMinute;
}
