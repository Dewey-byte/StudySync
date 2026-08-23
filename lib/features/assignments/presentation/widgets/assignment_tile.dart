import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_time_x.dart';
import '../../../../shared/widgets/app_scaffolding.dart';
import '../../domain/entities/assignment.dart';

/// Colour used for a priority across the tracker.
Color priorityColor(AssignmentPriority priority) => switch (priority) {
  AssignmentPriority.high => AppTheme.high,
  AssignmentPriority.medium => AppTheme.medium,
  AssignmentPriority.low => AppTheme.low,
};

IconData categoryIcon(AssignmentCategory category) => switch (category) {
  AssignmentCategory.assignment => Icons.assignment_outlined,
  AssignmentCategory.project => Icons.workspaces_outline,
  AssignmentCategory.quiz => Icons.quiz_outlined,
  AssignmentCategory.exam => Icons.school_outlined,
};

/// One row in the assignment list.
///
/// Pass a null [onToggle] to render it read-only, which is what the dashboard
/// does.
class AssignmentTile extends StatelessWidget {
  const AssignmentTile({
    required this.assignment,
    this.onTap,
    this.onToggle,
    super.key,
  });

  final Assignment assignment;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = priorityColor(assignment.priority);
    final isCompleted = assignment.isCompleted;

    return AppCard(
      onTap: onTap,
      borderColor: assignment.isOverdue
          ? AppTheme.high.withValues(alpha: 0.45)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (onToggle != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Checkbox(
                value: isCompleted,
                onChanged: (_) => onToggle!.call(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 2),
              child: Icon(
                categoryIcon(assignment.category),
                size: 20,
                color: accent,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  assignment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: assignment.isOverdue
                          ? AppTheme.high
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : '${AppDateFormat.dayMonth.format(assignment.dueAt)}'
                                  ' • ${AppDateFormat.relativeToNow(assignment.dueAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: assignment.isOverdue
                              ? AppTheme.high
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: assignment.isOverdue
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    StatusPill(
                      label: assignment.category.label,
                      color: theme.colorScheme.primary,
                      icon: categoryIcon(assignment.category),
                    ),
                    StatusPill(
                      label: assignment.priority.label,
                      color: accent,
                    ),
                    if (assignment.courseCode != null &&
                        assignment.courseCode!.isNotEmpty)
                      StatusPill(
                        label: assignment.courseCode!,
                        color: Color(
                          assignment.courseColorValue ?? AppTheme.info.toARGB32(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
