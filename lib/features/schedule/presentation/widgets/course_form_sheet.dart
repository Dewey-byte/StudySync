import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../domain/entities/course.dart';
import '../controllers/schedule_controller.dart';

/// Create/edit form for a course.
class CourseFormSheet extends ConsumerStatefulWidget {
  const CourseFormSheet({this.existing, super.key});

  final Course? existing;

  static Future<bool?> show(BuildContext context, {Course? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CourseFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<CourseFormSheet> createState() => _CourseFormSheetState();
}

class _CourseFormSheetState extends ConsumerState<CourseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _titleController;
  late final TextEditingController _instructorController;
  late int _colorValue;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _codeController = TextEditingController(text: existing?.code ?? '');
    _titleController = TextEditingController(text: existing?.title ?? '');
    _instructorController = TextEditingController(
      text: existing?.instructor ?? '',
    );
    _colorValue = existing?.colorValue ?? Course.palette.first;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _instructorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = ref.read(scheduleControllerProvider);
    final existing = widget.existing;

    final error = existing == null
        ? await controller.createCourse(
            code: _codeController.text,
            title: _titleController.text,
            instructor: _instructorController.text,
            colorValue: _colorValue,
          )
        : await controller.updateCourse(
            existing.copyWith(
              code: _codeController.text,
              title: _titleController.text,
              instructor: _instructorController.text,
              colorValue: _colorValue,
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: <Widget>[
            Text(
              widget.existing == null ? 'New course' : 'Edit course',
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
            LabeledField(
              label: 'Course title',
              controller: _titleController,
              hint: 'e.g. Mobile Development',
              maxLength: 100,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  Validators.requiredText(value, field: 'Course title'),
            ),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Code (optional)',
              controller: _codeController,
              hint: 'e.g. IT 126',
              maxLength: 20,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Instructor (optional)',
              controller: _instructorController,
              hint: 'e.g. Prof. Santos',
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            _ColorPicker(
              selected: _colorValue,
              onChanged: (value) => setState(() => _colorValue = value),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(
                      widget.existing == null ? 'Add course' : 'Save changes',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Colour',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: Course.palette.map((value) {
            final isSelected = value == selected;
            return GestureDetector(
              onTap: () => onChanged(value),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}
