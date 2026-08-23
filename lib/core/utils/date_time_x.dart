import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date and time formatting used across the feature screens.
abstract final class AppDateFormat {
  static final DateFormat dayMonth = DateFormat('EEE, d MMM');
  static final DateFormat dayMonthYear = DateFormat('EEE, d MMM yyyy');
  static final DateFormat time = DateFormat('h:mm a');
  static final DateFormat full = DateFormat('EEE, d MMM yyyy • h:mm a');
  static final DateFormat monthYear = DateFormat('MMMM yyyy');

  static const List<String> weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> weekdayShortNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// [weekday] follows [DateTime.monday] .. [DateTime.sunday].
  static String weekdayName(int weekday) => weekdayNames[(weekday - 1) % 7];

  static String weekdayShortName(int weekday) =>
      weekdayShortNames[(weekday - 1) % 7];

  static String minuteOfDay(int minutes) {
    final normalised = minutes % (24 * 60);
    final base = DateTime(2000, 1, 1, normalised ~/ 60, normalised % 60);
    return time.format(base);
  }

  /// "in 3 days", "in 2 hours", "4 days overdue".
  static String relativeToNow(DateTime target, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final delta = target.difference(reference);
    final overdue = delta.isNegative;
    final magnitude = delta.abs();

    final String amount;
    if (magnitude.inDays >= 1) {
      final days = magnitude.inDays;
      amount = '$days ${days == 1 ? 'day' : 'days'}';
    } else if (magnitude.inHours >= 1) {
      final hours = magnitude.inHours;
      amount = '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      final minutes = magnitude.inMinutes.clamp(1, 59);
      amount = '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }

    return overdue ? '$amount overdue' : 'in $amount';
  }

  static String reminderLabel(int minutesBefore) => switch (minutesBefore) {
    0 => 'At the time it starts',
    < 60 => '$minutesBefore minutes before',
    60 => '1 hour before',
    < 1440 => '${minutesBefore ~/ 60} hours before',
    1440 => '1 day before',
    < 10080 => '${minutesBefore ~/ 1440} days before',
    _ => '${minutesBefore ~/ 10080} weeks before',
  };
}

extension DateTimeX on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Monday of the week this date falls in.
  DateTime get startOfWeek =>
      startOfDay.subtract(Duration(days: weekday - DateTime.monday));

  int get minuteOfDay => hour * 60 + minute;

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDayAs(DateTime.now());

  bool get isTomorrow =>
      isSameDayAs(DateTime.now().add(const Duration(days: 1)));

  DateTime withTime(TimeOfDay timeOfDay) =>
      DateTime(year, month, day, timeOfDay.hour, timeOfDay.minute);
}

extension TimeOfDayX on TimeOfDay {
  int get minuteOfDay => hour * 60 + minute;

  static TimeOfDay fromMinuteOfDay(int minutes) {
    final normalised = minutes % (24 * 60);
    return TimeOfDay(hour: normalised ~/ 60, minute: normalised % 60);
  }
}
