import 'package:add_2_calendar/add_2_calendar.dart' as calendar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_time_x.dart';
import '../../../../shared/widgets/app_scaffolding.dart';
import '../../domain/entities/class_session.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/class_session_form_sheet.dart';
import 'courses_page.dart';

/// Class Schedule Manager: a weekday-by-weekday timetable.
class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedWeekdayProvider);
    final week = ref.watch(weeklyScheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Manage courses',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CoursesPage()),
            ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _WeekdaySelector(
            selected: selectedDay,
            countsByDay: week.valueOrNull?.map(
              (day, classes) => MapEntry<int, int>(day, classes.length),
            ),
            onChanged: (day) =>
                ref.read(selectedWeekdayProvider.notifier).state = day,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            ClassSessionFormSheet.show(context, dayOfWeek: selectedDay),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add class'),
      ),
      body: week.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: 'We could not load your timetable.',
          onRetry: () => ref.invalidate(weeklyScheduleProvider),
        ),
        data: (byDay) {
          final classes = byDay[selectedDay] ?? const <ScheduledClass>[];
          if (classes.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No classes on ${AppDateFormat.weekdayName(selectedDay)}',
              message:
                  'Add your weekly classes and StudySync will remind you '
                  'before each one starts.',
              action: FilledButton.icon(
                onPressed: () =>
                    ClassSessionFormSheet.show(context, dayOfWeek: selectedDay),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a class'),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: classes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _ClassCard(scheduled: classes[index]),
          );
        },
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({
    required this.selected,
    required this.onChanged,
    this.countsByDay,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final Map<int, int>? countsByDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now().weekday;

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          final isSelected = day == selected;
          final count = countsByDay?[day] ?? 0;

          return GestureDetector(
            onTap: () => onChanged(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 54,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                borderRadius: BorderRadius.circular(14),
                border: day == today && !isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 1.4)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    AppDateFormat.weekdayShortName(day),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: count == 0
                          ? Colors.transparent
                          : (isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.scheduled});

  final ScheduledClass scheduled;

  /// Hands the next occurrence to the device calendar app, which is the
  /// calendar integration the app promises without needing calendar
  /// read permissions.
  void _addToDeviceCalendar() {
    final session = scheduled.session;
    final start = session.nextOccurrence();

    calendar.Add2Calendar.addEvent2Cal(
      calendar.Event(
        title: scheduled.course.displayName,
        location: session.room,
        startDate: start,
        endDate: start.add(session.duration),
        recurrence: calendar.Recurrence(
          frequency: calendar.Frequency.weekly,
          ocurrences: 16,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this class?'),
        content: Text(
          '${scheduled.course.displayName} on '
          '${AppDateFormat.weekdayName(scheduled.session.dayOfWeek)} will be '
          'removed from your timetable.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    final error = await ref
        .read(scheduleControllerProvider)
        .deleteSession(scheduled.session);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final course = scheduled.course;
    final session = scheduled.session;
    final isNow = scheduled.isHappeningAt(DateTime.now());

    return AppCard(
      borderColor: isNow ? course.color.withValues(alpha: 0.6) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Text(
                AppDateFormat.minuteOfDay(session.startMinute),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: course.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppDateFormat.minuteOfDay(session.endMinute),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isNow)
                      const StatusPill(label: 'NOW', color: Color(0xFF10B981)),
                  ],
                ),
                if (course.code.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    course.code,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: course.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: <Widget>[
                    if (session.room.isNotEmpty)
                      _MetaText(
                        icon: Icons.place_outlined,
                        label: session.room,
                      ),
                    if (course.instructor.isNotEmpty)
                      _MetaText(
                        icon: Icons.person_outline_rounded,
                        label: course.instructor,
                      ),
                    _MetaText(
                      icon: Icons.notifications_outlined,
                      label: AppDateFormat.reminderLabel(
                        session.reminderMinutes,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (value) {
              if (value == 'calendar') {
                _addToDeviceCalendar();
              } else if (value == 'delete') {
                _confirmDelete(context, ref);
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'calendar',
                child: ListTile(
                  leading: Icon(Icons.calendar_month_outlined),
                  title: Text('Add to device calendar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Remove class'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
