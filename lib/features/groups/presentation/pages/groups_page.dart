import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_time_x.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_scaffolding.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../domain/entities/study_group.dart';
import '../controllers/group_controller.dart';

/// Group Collaboration Hub: the list of the student's project groups.
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => GroupFormSheet.show(context),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('New group'),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: 'We could not load your groups.',
          onRetry: () => ref.invalidate(groupListProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.groups_outlined,
                title: 'No groups yet',
                message:
                    'Create a group for a project or organisation to share '
                    'tasks, announcements and meeting schedules.',
                action: FilledButton.icon(
                  onPressed: () => GroupFormSheet.show(context),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Create a group'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 52),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(groupListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _GroupCard(overview: items[index]),
                ),
              ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.overview});

  final GroupOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = overview.group;

    return AppCard(
      onTap: () => context.go('/groups/${group.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${overview.memberCount} '
                      '${overview.memberCount == 1 ? 'member' : 'members'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          if (group.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              group.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              StatusPill(
                label: 'Code ${group.joinCode}',
                color: theme.colorScheme.primary,
                icon: Icons.key_rounded,
              ),
              if (overview.openTaskCount > 0)
                StatusPill(
                  label: '${overview.openTaskCount} open',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.checklist_rounded,
                ),
              if (overview.nextMeetingAt != null)
                StatusPill(
                  label: AppDateFormat.dayMonth.format(overview.nextMeetingAt!),
                  color: const Color(0xFF0EA5E9),
                  icon: Icons.event_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create/edit form for a group.
class GroupFormSheet extends ConsumerStatefulWidget {
  const GroupFormSheet({this.existing, super.key});

  final StudyGroup? existing;

  static Future<bool?> show(BuildContext context, {StudyGroup? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => GroupFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends ConsumerState<GroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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

    final controller = ref.read(groupControllerProvider);
    final existing = widget.existing;

    final error = existing == null
        ? await controller.createGroup(
            name: _nameController.text,
            description: _descriptionController.text,
          )
        : await controller.updateGroup(
            existing.copyWith(
              name: _nameController.text,
              description: _descriptionController.text,
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
              widget.existing == null ? 'New group' : 'Edit group',
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
              label: 'Group name',
              controller: _nameController,
              hint: 'e.g. Capstone Team 4',
              maxLength: 80,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  Validators.requiredText(value, field: 'Group name'),
            ),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Description (optional)',
              controller: _descriptionController,
              hint: 'What is this group working on?',
              maxLines: 3,
              maxLength: 500,
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
                      widget.existing == null
                          ? 'Create group'
                          : 'Save changes',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies a group's join code to the clipboard.
Future<void> copyJoinCode(BuildContext context, String joinCode) async {
  await Clipboard.setData(ClipboardData(text: joinCode));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group code $joinCode copied')),
    );
  }
}
