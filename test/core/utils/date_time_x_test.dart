import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/core/utils/date_time_x.dart';

void main() {
  group('AppDateFormat.relativeToNow', () {
    final now = DateTime(2026, 8, 16, 12);

    test('describes future moments', () {
      expect(
        AppDateFormat.relativeToNow(now.add(const Duration(days: 3)), now: now),
        'in 3 days',
      );
      expect(
        AppDateFormat.relativeToNow(now.add(const Duration(hours: 2)), now: now),
        'in 2 hours',
      );
      expect(
        AppDateFormat.relativeToNow(
          now.add(const Duration(minutes: 30)),
          now: now,
        ),
        'in 30 minutes',
      );
    });

    test('describes past moments as overdue', () {
      expect(
        AppDateFormat.relativeToNow(
          now.subtract(const Duration(days: 1)),
          now: now,
        ),
        '1 day overdue',
      );
      expect(
        AppDateFormat.relativeToNow(
          now.subtract(const Duration(hours: 5)),
          now: now,
        ),
        '5 hours overdue',
      );
    });
  });

  group('AppDateFormat.reminderLabel', () {
    test('picks a sensible unit for each lead time', () {
      expect(AppDateFormat.reminderLabel(0), 'At the time it starts');
      expect(AppDateFormat.reminderLabel(15), '15 minutes before');
      expect(AppDateFormat.reminderLabel(60), '1 hour before');
      expect(AppDateFormat.reminderLabel(180), '3 hours before');
      expect(AppDateFormat.reminderLabel(1440), '1 day before');
      expect(AppDateFormat.reminderLabel(2880), '2 days before');
    });
  });

  group('AppDateFormat.weekdayName', () {
    test('maps DateTime weekday constants', () {
      expect(AppDateFormat.weekdayName(DateTime.monday), 'Monday');
      expect(AppDateFormat.weekdayName(DateTime.sunday), 'Sunday');
      expect(AppDateFormat.weekdayShortName(DateTime.wednesday), 'Wed');
    });
  });

  group('DateTimeX', () {
    test('startOfWeek returns the Monday of that week', () {
      // 2026-08-16 is a Sunday.
      expect(DateTime(2026, 8, 16).startOfWeek, DateTime(2026, 8, 10));
      expect(DateTime(2026, 8, 10).startOfWeek, DateTime(2026, 8, 10));
    });

    test('minuteOfDay counts minutes past midnight', () {
      expect(DateTime(2026, 8, 16, 9, 30).minuteOfDay, 570);
      expect(DateTime(2026, 8, 16).minuteOfDay, 0);
    });

    test('withTime replaces only the clock component', () {
      final result = DateTime(
        2026,
        8,
        16,
        3,
        15,
      ).withTime(const TimeOfDay(hour: 23, minute: 59));

      expect(result, DateTime(2026, 8, 16, 23, 59));
    });

    test('isSameDayAs ignores the time', () {
      expect(
        DateTime(2026, 8, 16, 1).isSameDayAs(DateTime(2026, 8, 16, 23)),
        isTrue,
      );
      expect(
        DateTime(2026, 8, 16).isSameDayAs(DateTime(2026, 8, 17)),
        isFalse,
      );
    });
  });

  group('TimeOfDayX', () {
    test('round-trips through minutes past midnight', () {
      const time = TimeOfDay(hour: 14, minute: 45);

      expect(time.minuteOfDay, 885);
      expect(TimeOfDayX.fromMinuteOfDay(885), time);
    });

    test('wraps values beyond a full day', () {
      expect(
        TimeOfDayX.fromMinuteOfDay(1440 + 90),
        const TimeOfDay(hour: 1, minute: 30),
      );
    });
  });
}
