import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_scaffolding.dart';
import '../../domain/entities/assignment.dart';
import '../controllers/assignment_controller.dart';
import '../widgets/assignment_form_sheet.dart';
import '../widgets/assignment_tile.dart';

/// Smart Assignment Tracker: everything due, grouped by the selected filter.
class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(assignmentFilterProvider);
    final assignments = ref.watch(assignmentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _FilterBar(
            selected: filter,
            onChanged: (value) =>
                ref.read(assignmentFilterProvider.notifier).state = value,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AssignmentFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: assignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: 'We could not load your tracker.',
          onRetry: () => ref.invalidate(assignmentListProvider),
        ),
        data: (items) => items.isEmpty
            ? _EmptyForFilter(filter: filter)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(assignmentListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _DismissibleAssignment(
                    assignment: items[index],
                  ),
                ),
              ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final AssignmentFilter selected;
  final ValueChanged<AssignmentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: AssignmentFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = AssignmentFilter.values[index];
          final isSelected = filter == selected;
          return ChoiceChip(
            label: Text(filter.label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onChanged(filter),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.16),
          );
        },
      ),
    );
  }
}

/// Swipe left to delete, tap to edit, checkbox to complete.
class _DismissibleAssignment extends ConsumerWidget {
  const _DismissibleAssignment({required this.assignment});

  final Assignment assignment;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(
          '"${assignment.title}" and its reminder will be removed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(assignmentListProvider.notifier);

    return Dismissible(
      key: ValueKey<String>(assignment.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        final error = await controller.delete(assignment);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: AssignmentTile(
        assignment: assignment,
        onTap: () => AssignmentFormSheet.show(context, existing: assignment),
        onToggle: () async {
          final error = await controller.toggleCompleted(assignment);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error)));
          }
        },
      ),
    );
  }
}

class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({required this.filter});

  final AssignmentFilter filter;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      AssignmentFilter.upcoming => EmptyState(
        icon: Icons.event_available_rounded,
        title: 'Nothing due yet',
        message:
            'Add your assignments, quizzes and exams and StudySync will '
            'remind you before each deadline.',
        action: FilledButton.icon(
          onPressed: () => AssignmentFormSheet.show(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add your first item'),
          style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
        ),
      ),
      AssignmentFilter.overdue => const EmptyState(
        icon: Icons.verified_rounded,
        title: 'Nothing overdue',
        message: 'You are on top of every deadline. Keep it up.',
      ),
      AssignmentFilter.completed => const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No completed work yet',
        message: 'Items you tick off will be collected here.',
      ),
      AssignmentFilter.all => const EmptyState(
        icon: Icons.checklist_rounded,
        title: 'Your tracker is empty',
        message: 'Anything you add will show up here.',
      ),
    };
  }
}
