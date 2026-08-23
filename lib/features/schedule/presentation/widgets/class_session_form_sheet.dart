import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_time_x.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/course.dart';
import '../controllers/schedule_controller.dart';
import 'course_form_sheet.dart';

/// Adds a weekly class meeting to a course.
class ClassSessionFormSheet extends ConsumerStatefulWidget {
  const ClassSessionFormSheet({required this.initialDayOfWeek, super.key});

  final int initialDayOfWeek;

  static Future<bool?> show(BuildContext context, {required int dayOfWeek}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          ClassSessionFormSheet(initialDayOfWeek: dayOfWeek),
    );
  }

  @override
  ConsumerState<ClassSessionFormSheet> createState() =>
      _ClassSessionFormSheetState();
}

class _ClassSessionFormSheetState extends ConsumerState<ClassSessionFormSheet> {
  final _roomController = TextEditingController();

  String? _courseId;
  late int _dayOfWeek;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);
  int _reminderMinutes = 15;

  bool _submitting = false;
  String? _error;
  List<ScheduledClass> _conflicts = const <ScheduledClass>[];

  @override
  void initState() {
    super.initState();
    _dayOfWeek = widget.initialDayOfWeek;
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _start = picked;
        // Keep the original length when the start moves.
        if (_end.minuteOfDay <= _start.minuteOfDay) {
          _end = TimeOfDayX.fromMinuteOfDay(_start.minuteOfDay + 90);
        }
      } else {
        _end = picked;
      }
    });
    await _refreshConflicts();
  }

  Future<void> _refreshConflicts() async {
    if (_end.minuteOfDay <= _start.minuteOfDay) return;

    final conflicts = await ref
        .read(scheduleControllerProvider)
        .findConflicts(
          dayOfWeek: _dayOfWeek,
          startMinute: _start.minuteOfDay,
          endMinute: _end.minuteOfDay,
        );
    if (mounted) setState(() => _conflicts = conflicts);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final courseId = _courseId;
    if (courseId == null) {
      setState(() => _error = 'Choose which course this class belongs to.');
      return;
    }
    if (_end.minuteOfDay <= _start.minuteOfDay) {
      setState(() => _error = 'End time must be after the start time.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(scheduleControllerProvider)
        .addSession(
          courseId: courseId,
          dayOfWeek: _dayOfWeek,
          startMinute: _start.minuteOfDay,
          endMinute: _end.minuteOfDay,
          room: _roomController.text,
          reminderMinutes: _reminderMinutes,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courses =
        ref.watch(courseListProvider).valueOrNull ?? const <Course>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text(
            'Add a class',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (courses.isEmpty)
            _NoCoursesPrompt(
              onCreate: () async {
                final created = await CourseFormSheet.show(context);
                if (created ?? false) ref.invalidate(courseListProvider);
              },
            )
          else ...<Widget>[
            ChoiceChipsField<String>(
              label: 'Course',
              values: courses.map((course) => course.id).toList(growable: false),
              selected: _courseId ?? '',
              labelBuilder: (id) {
                final course = courses.firstWhere((c) => c.id == id);
                return course.code.isEmpty ? course.title : course.code;
              },
              colorBuilder: (id) =>
                  courses.firstWhere((c) => c.id == id).color,
              onChanged: (id) => setState(() => _courseId = id),
            ),
            const SizedBox(height: 18),
            ChoiceChipsField<int>(
              label: 'Day',
              values: const <int>[1, 2, 3, 4, 5, 6, 7],
              selected: _dayOfWeek,
              labelBuilder: AppDateFormat.weekdayShortName,
              onChanged: (day) {
                setState(() => _dayOfWeek = day);
                _refreshConflicts();
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: PickerField(
                    label: 'Starts',
                    icon: Icons.play_arrow_rounded,
                    value: AppDateFormat.minuteOfDay(_start.minuteOfDay),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PickerField(
                    label: 'Ends',
                    icon: Icons.stop_rounded,
                    value: AppDateFormat.minuteOfDay(_end.minuteOfDay),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            if (_conflicts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _ConflictWarning(conflicts: _conflicts),
            ],
            const SizedBox(height: 18),
            LabeledField(
              label: 'Room (optional)',
              controller: _roomController,
              hint: 'e.g. Room 214',
              maxLength: 40,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 18),
            ReminderPicker(
              value: _reminderMinutes,
              options: const <int>[0, 5, 10, 15, 30, 60],
              label: 'Remind me before class',
              onChanged: (value) => setState(() => _reminderMinutes = value),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Add to timetable'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoCoursesPrompt extends StatelessWidget {
  const _NoCoursesPrompt({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Text(
          'Add a course first, then you can schedule its weekly classes.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a course'),
        ),
      ],
    );
  }
}

class _ConflictWarning extends StatelessWidget {
  const _ConflictWarning({required this.conflicts});

  final List<ScheduledClass> conflicts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = conflicts
        .map((scheduled) => scheduled.course.title)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This overlaps with $names. You can still save it if the clash '
              'is intentional.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
