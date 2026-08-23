import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_time_x.dart';
import '../../../../shared/widgets/app_scaffolding.dart';
import '../../../assignments/presentation/widgets/assignment_tile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../groups/domain/entities/study_group.dart';
import '../../../schedule/domain/entities/class_session.dart';
import '../controllers/dashboard_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              message: 'We could not load your dashboard.',
              onRetry: () => ref.invalidate(dashboardProvider),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: <Widget>[
                _GreetingHeader(name: user?.firstName ?? 'there'),
                const SizedBox(height: 24),
                _StatRow(counts: data.counts),
                const SizedBox(height: 28),
                if (data.remainingClassesToday.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'Classes left today',
                    action: TextButton(
                      onPressed: () => context.go(AppRoute.schedule.path),
                      child: const Text('Timetable'),
                    ),
                  ),
                  ...data.remainingClassesToday.map(
                    (scheduled) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ClassRow(scheduled: scheduled),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                SectionHeader(
                  title: 'Upcoming deadlines',
                  action: TextButton(
                    onPressed: () => context.go(AppRoute.assignments.path),
                    child: const Text('See all'),
                  ),
                ),
                if (data.upcomingAssignments.isEmpty)
                  const _QuietCard(
                    icon: Icons.task_alt_rounded,
                    message: 'Nothing due right now. Enjoy the breathing room.',
                  )
                else
                  ...data.upcomingAssignments.map(
                    (assignment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AssignmentTile(
                        assignment: assignment,
                        onTap: () => context.go(AppRoute.assignments.path),
                        onToggle: null,
                      ),
                    ),
                  ),
                if (data.upcomingMeetings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Group meetings',
                    action: TextButton(
                      onPressed: () => context.go(AppRoute.groups.path),
                      child: const Text('Groups'),
                    ),
                  ),
                  ...data.upcomingMeetings.map(
                    (meeting) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MeetingRow(meeting: meeting),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String name;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _greeting,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppDateFormat.dayMonthYear.format(DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => context.push(AppRoute.settings.path),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.counts});

  final ({int dueToday, int overdue, int completed}) counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            label: 'Due today',
            value: counts.dueToday,
            color: AppTheme.info,
            icon: Icons.today_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Overdue',
            value: counts.overdue,
            color: AppTheme.high,
            icon: Icons.priority_high_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Done',
            value: counts.completed,
            color: AppTheme.low,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.scheduled});

  final ScheduledClass scheduled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = scheduled.course;
    final session = scheduled.session;
    final isNow = scheduled.isHappeningAt(DateTime.now());

    return AppCard(
      borderColor: isNow ? course.color.withValues(alpha: 0.6) : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: course.color,
              borderRadius: BorderRadius.circular(2),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session.room.isEmpty
                      ? session.timeRange
                      : '${session.timeRange} • ${session.room}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isNow)
            const StatusPill(label: 'NOW', color: AppTheme.low)
          else
            Text(
              AppDateFormat.minuteOfDay(session.startMinute),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting});

  final GroupMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.event_rounded,
              size: 18,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meeting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppDateFormat.full.format(meeting.scheduledAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}