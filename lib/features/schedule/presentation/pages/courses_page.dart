import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_scaffolding.dart';
import '../../domain/entities/course.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/course_form_sheet.dart';

/// Manage the list of subjects that classes and assignments attach to.
class CoursesPage extends ConsumerWidget {
  const CoursesPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${course.title}?'),
        content: const Text(
          'Its classes and reminders will be removed. Assignments linked to '
          'it are kept, but will no longer show the course tag.',
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
    if (!(confirmed ?? false)) return;

    final error = await ref.read(scheduleControllerProvider).deleteCourse(
      course,
    );
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseListProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Courses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CourseFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add course'),
      ),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: 'We could not load your courses.',
          onRetry: () => ref.invalidate(courseListProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No courses yet',
                message:
                    'Add the subjects you are enrolled in so you can build a '
                    'timetable and tag your assignments.',
                action: FilledButton.icon(
                  onPressed: () => CourseFormSheet.show(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a course'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 52),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final course = items[index];
                  return AppCard(
                    onTap: () =>
                        CourseFormSheet.show(context, existing: course),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: course.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 20,
                            color: course.color,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                course.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                <String>[
                                  if (course.code.isNotEmpty) course.code,
                                  if (course.instructor.isNotEmpty)
                                    course.instructor,
                                ].join(' • '),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete course',
                          onPressed: () => _confirmDelete(context, ref, course),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
