import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_time_x.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../schedule/domain/entities/course.dart';
import '../../../schedule/presentation/controllers/schedule_controller.dart';
import '../../domain/entities/assignment.dart';
import '../controllers/assignment_controller.dart';
import 'assignment_tile.dart';

/// Create/edit form for an assignment, shown as a draggable bottom sheet.
///
/// Returns true through the navigator when a save succeeded.
class AssignmentFormSheet extends ConsumerStatefulWidget {
  const AssignmentFormSheet({this.existing, super.key});

  final Assignment? existing;

  static Future<bool?> show(BuildContext context, {Assignment? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AssignmentFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<AssignmentFormSheet> createState() =>
      _AssignmentFormSheetState();
}

class _AssignmentFormSheetState extends ConsumerState<AssignmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;

  late AssignmentCategory _category;
  late AssignmentPriority _priority;
  late DateTime _dueAt;
  late int _reminderMinutes;
  String? _courseId;

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _detailsController = TextEditingController(text: existing?.details ?? '');
    _category = existing?.category ?? AssignmentCategory.assignment;
    _priority = existing?.priority ?? AssignmentPriority.medium;
    _reminderMinutes = existing?.reminderMinutes ?? 1440;
    _courseId = existing?.courseId;
    _dueAt =
        existing?.dueAt ??
        DateTime.now()
            .add(const Duration(days: 1))
            .startOfDay
            .add(const Duration(hours: 23, minutes: 59));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (!mounted) return;

    setState(() {
      _dueAt = date.withTime(time ?? TimeOfDay.fromDateTime(_dueAt));
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = ref.read(assignmentListProvider.notifier);
    final existing = widget.existing;

    final error = existing == null
        ? await controller.create(
            title: _titleController.text,
            details: _detailsController.text,
            category: _category,
            priority: _priority,
            dueAt: _dueAt,
            reminderMinutes: _reminderMinutes,
            courseId: _courseId,
          )
        : await controller.saveEdits(
            existing.copyWith(
              title: _titleController.text,
              details: _detailsController.text,
              category: _category,
              priority: _priority,
              dueAt: _dueAt,
              reminderMinutes: _reminderMinutes,
              courseId: _courseId,
              clearCourse: _courseId == null,
            ),
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
    final courses = ref.watch(courseListProvider).valueOrNull ?? const <Course>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isEditing ? 'Edit item' : 'New item',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              LabeledField(
                label: 'Title',
                controller: _titleController,
                hint: 'e.g. Research paper draft',
                maxLength: 120,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    Validators.requiredText(value, field: 'Title'),
              ),
              const SizedBox(height: 18),
              ChoiceChipsField<AssignmentCategory>(
                label: 'Type',
                values: AssignmentCategory.values,
                selected: _category,
                labelBuilder: (value) => value.label,
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 18),
              ChoiceChipsField<AssignmentPriority>(
                label: 'Priority',
                values: AssignmentPriority.values,
                selected: _priority,
                labelBuilder: (value) => value.label,
                colorBuilder: priorityColor,
                onChanged: (value) => setState(() => _priority = value),
              ),
              const SizedBox(height: 18),
              PickerField(
                label: 'Due',
                icon: Icons.event_rounded,
                value: AppDateFormat.full.format(_dueAt),
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 18),
              _CoursePicker(
                courses: courses,
                selectedId: _courseId,
                onChanged: (value) => setState(() => _courseId = value),
              ),
              const SizedBox(height: 18),
              ReminderPicker(
                value: _reminderMinutes,
                onChanged: (value) => setState(() => _reminderMinutes = value),
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Notes (optional)',
                controller: _detailsController,
                hint: 'Requirements, links, reminders to yourself…',
                maxLines: 4,
                maxLength: 500,
                validator: (value) =>
                    Validators.optionalText(value, field: 'Notes'),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Add to tracker'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoursePicker extends StatelessWidget {
  const _CoursePicker({
    required this.courses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Course> courses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (courses.isEmpty) {
      return Text(
        'Add a course in the Schedule tab to link work to a subject.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Course (optional)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('None'),
              selected: selectedId == null,
              showCheckmark: false,
              onSelected: (_) => onChanged(null),
            ),
            ...courses.map(
              (course) => ChoiceChip(
                label: Text(
                  course.code.isEmpty ? course.title : course.code,
                ),
                selected: selectedId == course.id,
                showCheckmark: false,
                selectedColor: course.color.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selectedId == course.id
                      ? course.color
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (_) => onChanged(course.id),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
