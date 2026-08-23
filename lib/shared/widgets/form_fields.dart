import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/date_time_x.dart';

/// Text field with a label above it, matching the app's form style.
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
    this.prefixIcon,
    this.suffix,
    this.onFieldSubmitted,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          enabled: enabled,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Password field with a visibility toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.label,
    required this.controller,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.hint,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final String? hint;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      validator: widget.validator,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      textCapitalization: TextCapitalization.none,
      prefixIcon: Icons.lock_outline_rounded,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffix: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
        ),
      ),
    );
  }
}

/// Read-only field that opens a picker when tapped.
class PickerField extends StatelessWidget {
  const PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder,
    super.key,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20),
            ),
            child: Text(
              hasValue ? value! : (placeholder ?? 'Select'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: hasValue
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal set of single-choice chips.
class ChoiceChipsField<T> extends StatelessWidget {
  const ChoiceChipsField({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.colorBuilder,
    super.key,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final Color Function(T value)? colorBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final isSelected = value == selected;
            final accent = colorBuilder?.call(value) ?? theme.colorScheme.primary;
            return ChoiceChip(
              label: Text(labelBuilder(value)),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onChanged(value);
              },
              showCheckmark: false,
              selectedColor: accent.withValues(alpha: 0.18),
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? accent : theme.colorScheme.onSurfaceVariant,
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

/// Standard reminder lead times offered across the app.
class ReminderPicker extends StatelessWidget {
  const ReminderPicker({
    required this.value,
    required this.onChanged,
    this.options = const <int>[0, 15, 30, 60, 180, 720, 1440, 2880],
    this.label = 'Remind me',
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final List<int> options;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ChoiceChipsField<int>(
      label: label,
      values: options,
      selected: value,
      labelBuilder: AppDateFormat.reminderLabel,
      onChanged: onChanged,
    );
  }
}
