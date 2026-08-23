import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_time_x.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../domain/entities/study_group.dart';
import '../controllers/group_controller.dart';

/// Shared frame for the small single-purpose sheets in the group detail
/// screen, so they all handle keyboard inset, errors and busy state the
/// same way.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onSubmit,
    required this.submitting,
    this.error,
    this.formKey,
  });

  final String title;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback onSubmit;
  final bool submitting;
  final String? error;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ...children,
        const SizedBox(height: 28),
        FilledButton(
          onPressed: submitting ? null : onSubmit,
          child: submitting
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Text(actionLabel),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: formKey == null
          ? content
          : Form(key: formKey, child: content),
    );
  }
}

/// Adds a member to a group by name.
class AddMemberSheet extends ConsumerStatefulWidget {
  const AddMemberSheet({required this.groupId, super.key});

  final String groupId;

  static Future<void> show(BuildContext context, String groupId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddMemberSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(groupControllerProvider)
        .addMember(
          groupId: widget.groupId,
          displayName: _nameController.text,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Add a member',
      formKey: _formKey,
      error: _error,
      submitting: _submitting,
      actionLabel: 'Add member',
      onSubmit: _submit,
      children: <Widget>[
        LabeledField(
          label: 'Name',
          controller: _nameController,
          hint: 'e.g. Maria Reyes',
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) =>
              Validators.requiredText(value, field: 'Member name'),
        ),
      ],
    );
  }
}

/// Creates a shared task and optionally assigns it to a member.
class AddGroupTaskSheet extends ConsumerStatefulWidget {
  const AddGroupTaskSheet({
    required this.groupId,
    required this.members,
    super.key,
  });

  final String groupId;
  final List<GroupMember> members;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required List<GroupMember> members,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          AddGroupTaskSheet(groupId: groupId, members: members),
    );
  }

  @override
  ConsumerState<AddGroupTaskSheet> createState() => _AddGroupTaskSheetState();
}

class _AddGroupTaskSheetState extends ConsumerState<AddGroupTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  String? _assigneeId;
  DateTime? _dueAt;
  bool _submitting = false;
  String? _error;

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
      initialDate: _dueAt ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (!mounted) return;

    setState(() {
      _dueAt = date.withTime(time ?? const TimeOfDay(hour: 23, minute: 59));
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(groupControllerProvider)
        .addTask(
          groupId: widget.groupId,
          title: _titleController.text,
          details: _detailsController.text,
          assigneeId: _assigneeId,
          dueAt: _dueAt,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'New group task',
      formKey: _formKey,
      error: _error,
      submitting: _submitting,
      actionLabel: 'Add task',
      onSubmit: _submit,
      children: <Widget>[
        LabeledField(
          label: 'Task',
          controller: _titleController,
          hint: 'e.g. Draft the methodology section',
          maxLength: 120,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              Validators.requiredText(value, field: 'Task title'),
        ),
        const SizedBox(height: 18),
        if (widget.members.isNotEmpty) ...<Widget>[
          ChoiceChipsField<String>(
            label: 'Assign to',
            values: <String>[
              '',
              ...widget.members.map((member) => member.id),
            ],
            selected: _assigneeId ?? '',
            labelBuilder: (id) => id.isEmpty
                ? 'Unassigned'
                : widget.members
                      .firstWhere((member) => member.id == id)
                      .displayName,
            onChanged: (id) =>
                setState(() => _assigneeId = id.isEmpty ? null : id),
          ),
          const SizedBox(height: 18),
        ],
        PickerField(
          label: 'Due (optional)',
          icon: Icons.event_rounded,
          value: _dueAt == null ? null : AppDateFormat.full.format(_dueAt!),
          placeholder: 'No deadline',
          onTap: _pickDueDate,
        ),
        const SizedBox(height: 18),
        LabeledField(
          label: 'Notes (optional)',
          controller: _detailsController,
          maxLines: 3,
          maxLength: 500,
        ),
      ],
    );
  }
}

/// Posts an announcement to everyone in the group.
class PostAnnouncementSheet extends ConsumerStatefulWidget {
  const PostAnnouncementSheet({required this.groupId, super.key});

  final String groupId;

  static Future<void> show(BuildContext context, String groupId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PostAnnouncementSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<PostAnnouncementSheet> createState() =>
      _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState
    extends ConsumerState<PostAnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(groupControllerProvider)
        .postAnnouncement(
          groupId: widget.groupId,
          message: _messageController.text,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Post an announcement',
      formKey: _formKey,
      error: _error,
      submitting: _submitting,
      actionLabel: 'Post',
      onSubmit: _submit,
      children: <Widget>[
        LabeledField(
          label: 'Message',
          controller: _messageController,
          hint: 'Share an update with the group',
          maxLines: 5,
          maxLength: 1000,
          validator: (value) =>
              Validators.requiredText(value, field: 'Announcement'),
        ),
      ],
    );
  }
}

/// Schedules a meeting and its reminder.
class ScheduleMeetingSheet extends ConsumerStatefulWidget {
  const ScheduleMeetingSheet({
    required this.groupId,
    required this.groupName,
    super.key,
  });

  final String groupId;
  final String groupName;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String groupName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          ScheduleMeetingSheet(groupId: groupId, groupName: groupName),
    );
  }

  @override
  ConsumerState<ScheduleMeetingSheet> createState() =>
      _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends ConsumerState<ScheduleMeetingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _scheduledAt;
  int _reminderMinutes = 30;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scheduledAt = DateTime.now()
        .add(const Duration(days: 1))
        .startOfDay
        .add(const Duration(hours: 10));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (!mounted) return;

    setState(() {
      _scheduledAt = date.withTime(
        time ?? TimeOfDay.fromDateTime(_scheduledAt),
      );
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(groupControllerProvider)
        .scheduleMeeting(
          groupId: widget.groupId,
          groupName: widget.groupName,
          title: _titleController.text,
          location: _locationController.text,
          scheduledAt: _scheduledAt,
          reminderMinutes: _reminderMinutes,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Schedule a meeting',
      formKey: _formKey,
      error: _error,
      submitting: _submitting,
      actionLabel: 'Schedule',
      onSubmit: _submit,
      children: <Widget>[
        LabeledField(
          label: 'Title',
          controller: _titleController,
          hint: 'e.g. Progress check-in',
          maxLength: 120,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              Validators.requiredText(value, field: 'Meeting title'),
        ),
        const SizedBox(height: 18),
        PickerField(
          label: 'When',
          icon: Icons.event_rounded,
          value: AppDateFormat.full.format(_scheduledAt),
          onTap: _pickDateTime,
        ),
        const SizedBox(height: 18),
        LabeledField(
          label: 'Location or link (optional)',
          controller: _locationController,
          hint: 'e.g. Library, 3rd floor',
          maxLength: 120,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 18),
        ReminderPicker(
          value: _reminderMinutes,
          options: const <int>[0, 15, 30, 60, 180, 1440],
          onChanged: (value) => setState(() => _reminderMinutes = value),
        ),
      ],
    );
  }
}
