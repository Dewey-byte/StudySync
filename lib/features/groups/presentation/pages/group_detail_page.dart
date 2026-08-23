import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_time_x.dart';
import '../../../../shared/widgets/app_scaffolding.dart';
import '../../domain/entities/study_group.dart';
import '../controllers/group_controller.dart';
import '../widgets/group_sheets.dart';
import 'groups_page.dart';

/// One group's tasks, announcements, meetings and members.
class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));

    return detail.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: ErrorView(
          message: 'This group could not be opened.',
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
      ),
      data: (data) => _GroupDetailView(detail: data),
    );
  }
}

class _GroupDetailView extends ConsumerWidget {
  const _GroupDetailView({required this.detail});

  final GroupDetail detail;

  Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${detail.group.name}?'),
        content: const Text(
          'All of its tasks, announcements, meetings and reminders will be '
          'permanently removed.',
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

    final error = await ref
        .read(groupControllerProvider)
        .deleteGroup(detail.group);
    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      context.go('/groups');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = detail.group;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(group.name, overflow: TextOverflow.ellipsis),
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'code') {
                  await copyJoinCode(context, group.joinCode);
                } else if (value == 'edit') {
                  await GroupFormSheet.show(context, existing: group);
                } else if (value == 'delete') {
                  await _confirmDeleteGroup(context, ref);
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'code',
                  child: ListTile(
                    leading: Icon(Icons.key_rounded),
                    title: Text('Copy join code'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit group'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete group'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: 'Tasks'),
              Tab(text: 'Announcements'),
              Tab(text: 'Meetings'),
              Tab(text: 'Members'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _TasksTab(detail: detail),
            _AnnouncementsTab(detail: detail),
            _MeetingsTab(detail: detail),
            _MembersTab(detail: detail),
          ],
        ),
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.detail});

  final GroupDetail detail;

  Color _statusColor(GroupTaskStatus status) => switch (status) {
    GroupTaskStatus.todo => AppTheme.medium,
    GroupTaskStatus.inProgress => AppTheme.info,
    GroupTaskStatus.done => AppTheme.low,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(groupControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddGroupTaskSheet.show(
          context,
          groupId: detail.group.id,
          members: detail.members,
        ),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add task'),
      ),
      body: detail.tasks.isEmpty
          ? const EmptyState(
              icon: Icons.checklist_rounded,
              title: 'No shared tasks yet',
              message:
                  'Break the project into tasks and assign them so everyone '
                  'knows what they are responsible for.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: <Widget>[
                _ProgressBar(ratio: detail.completionRatio),
                const SizedBox(height: 20),
                ...detail.tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => controller.cycleTaskStatus(task),
                      onLongPress: () => controller.deleteTask(task),
                      borderColor: task.isOverdue
                          ? AppTheme.high.withValues(alpha: 0.45)
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            task.isDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: _statusColor(task.status),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  task.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: task.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.isDone
                                        ? theme.colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                if (task.details.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 5),
                                  Text(
                                    task.details,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    StatusPill(
                                      label: task.status.label,
                                      color: _statusColor(task.status),
                                    ),
                                    if (task.assigneeName != null)
                                      StatusPill(
                                        label: task.assigneeName!,
                                        color: theme.colorScheme.primary,
                                        icon: Icons.person_outline_rounded,
                                      ),
                                    if (task.dueAt != null)
                                      StatusPill(
                                        label: AppDateFormat.dayMonth.format(
                                          task.dueAt!,
                                        ),
                                        color: task.isOverdue
                                            ? AppTheme.high
                                            : theme.colorScheme.onSurfaceVariant,
                                        icon: Icons.schedule_rounded,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap a task to move it forward, long-press to delete.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Group progress',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsTab extends ConsumerWidget {
  const _AnnouncementsTab({required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PostAnnouncementSheet.show(context, detail.group.id),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post'),
      ),
      body: detail.announcements.isEmpty
          ? const EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements',
              message:
                  'Post updates here so nobody misses an important change of '
                  'plan.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: detail.announcements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final announcement = detail.announcements[index];
                return AppCard(
                  onLongPress: () => ref
                      .read(groupControllerProvider)
                      .deleteAnnouncement(announcement),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              announcement.authorName.isEmpty
                                  ? '?'
                                  : announcement.authorName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              announcement.authorName,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            AppDateFormat.dayMonth.format(
                              announcement.createdAt,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        announcement.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MeetingsTab extends ConsumerWidget {
  const _MeetingsTab({required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScheduleMeetingSheet.show(
          context,
          groupId: detail.group.id,
          groupName: detail.group.name,
        ),
        icon: const Icon(Icons.event_rounded),
        label: const Text('Schedule'),
      ),
      body: detail.meetings.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No meetings scheduled',
              message:
                  'Schedule a meeting and everyone gets a reminder before it '
                  'starts.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: detail.meetings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final meeting = detail.meetings[index];
                return AppCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: meeting.isPast
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.event_rounded,
                          size: 18,
                          color: meeting.isPast
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              meeting.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: meeting.isPast
                                    ? theme.colorScheme.onSurfaceVariant
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppDateFormat.full.format(meeting.scheduledAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (meeting.location.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 3),
                              Text(
                                meeting.location,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel meeting',
                        onPressed: () => ref
                            .read(groupControllerProvider)
                            .cancelMeeting(meeting),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddMemberSheet.show(context, detail.group.id),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add member'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: <Widget>[
          AppCard(
            onTap: () => copyJoinCode(context, detail.group.joinCode),
            child: Row(
              children: <Widget>[
                Icon(Icons.key_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Join code',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail.group.joinCode,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.copy_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...detail.members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        member.initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusPill(
                      label: member.role.label,
                      color: member.role == GroupRole.owner
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    if (member.role != GroupRole.owner)
                      IconButton(
                        tooltip: 'Remove member',
                        onPressed: () =>
                            ref.read(groupControllerProvider).removeMember(
                              groupId: detail.group.id,
                              memberId: member.id,
                            ),
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
