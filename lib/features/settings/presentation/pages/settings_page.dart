import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_scaffolding.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../assignments/presentation/controllers/assignment_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../schedule/presentation/controllers/schedule_controller.dart';

/// Whether app lock is currently switched on, read from secure storage.
final biometricUnlockEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(secureKeyStoreProvider).isBiometricUnlockEnabled(),
);

/// Whether this device offers biometrics at all.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isAvailable(),
);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: <Widget>[
          if (user != null) _ProfileCard(name: user.fullName, email: user.email),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Security'),
          const _BiometricTile(),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => _ChangePasswordSheet.show(context),
            child: const _SettingRow(
              icon: Icons.password_rounded,
              title: 'Change password',
              subtitle: 'Update the password used to unlock your account',
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => ref.read(authControllerProvider.notifier).lock(),
            child: const _SettingRow(
              icon: Icons.lock_outline_rounded,
              title: 'Lock now',
              subtitle: 'Require verification before the app can be used again',
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Notifications'),
          const _NotificationTile(),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Account'),
          AppCard(
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const _SettingRow(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: 'Your data stays encrypted on this device',
            ),
          ),
          const SizedBox(height: 10),
          const _DeleteAccountTile(),
          const SizedBox(height: 32),
          const _PrivacyNote(),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: destructive ? theme.colorScheme.error : null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _BiometricTile extends ConsumerWidget {
  const _BiometricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final enabled = ref.watch(biometricUnlockEnabledProvider).valueOrNull ?? false;

    return AppCard(
      child: _SettingRow(
        icon: Icons.fingerprint_rounded,
        title: 'Biometric app lock',
        subtitle: available
            ? 'Verify with your fingerprint or face each time you open the app'
            : 'This device has no biometrics enrolled',
        trailing: Switch(
          value: enabled,
          onChanged: available
              ? (value) async {
                  final result = await ref
                      .read(authControllerProvider.notifier)
                      .setBiometricUnlock(value);
                  ref.invalidate(biometricUnlockEnabledProvider);

                  if (value && !result && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Biometric lock was not turned on because '
                          'verification failed.',
                        ),
                      ),
                    );
                  }
                }
              : null,
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerStatefulWidget {
  const _NotificationTile();

  @override
  ConsumerState<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends ConsumerState<_NotificationTile> {
  bool _busy = false;

  /// Asks for permission and then re-registers every future reminder, which
  /// repairs alarms lost to a reboot or a permission that was only just
  /// granted.
  Future<void> _enableAndReschedule() async {
    setState(() => _busy = true);

    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermissions();

    final user = ref.read(currentUserProvider);
    var rescheduled = 0;
    if (user != null) {
      final assignments = await ref
          .read(assignmentRepositoryProvider)
          .rescheduleAllReminders(user.id);
      final classes = await ref
          .read(scheduleRepositoryProvider)
          .rescheduleAllReminders(user.id);
      rescheduled =
          (assignments.valueOrNull ?? 0) + (classes.valueOrNull ?? 0);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? '$rescheduled reminders are scheduled.'
              : 'Notifications are turned off for StudySync in system settings.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: _busy ? null : _enableAndReschedule,
      child: _SettingRow(
        icon: Icons.notifications_active_outlined,
        title: 'Reminders',
        subtitle:
            'Allow notifications and re-schedule every upcoming deadline, '
            'class and meeting',
        trailing: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _DeleteAccountTile extends ConsumerWidget {
  const _DeleteAccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => _DeleteAccountSheet.show(context),
      child: const _SettingRow(
        icon: Icons.delete_forever_outlined,
        title: 'Delete account and data',
        subtitle: 'Permanently removes your courses, tasks and groups',
        destructive: true,
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'StudySync works entirely offline. Your database is encrypted '
              'with a key held in this device\'s secure hardware, and nothing '
              'is uploaded to a server.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ChangePasswordSheet(),
    );
  }

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
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
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
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
              'Change password',
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
            PasswordField(
              label: 'Current password',
              controller: _currentController,
              textInputAction: TextInputAction.next,
              validator: (value) => (value ?? '').isEmpty
                  ? 'Enter your current password.'
                  : null,
            ),
            const SizedBox(height: 18),
            PasswordField(
              label: 'New password',
              controller: _newController,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            const SizedBox(height: 18),
            PasswordField(
              label: 'Confirm new password',
              controller: _confirmController,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) =>
                  Validators.confirmPassword(value, _newController.text),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _DeleteAccountSheet(),
    );
  }

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(_passwordController.text);

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
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text(
            'Delete your account',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Every course, class, assignment and group you created will be '
            'permanently deleted from this device. This cannot be undone.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          PasswordField(
            label: 'Confirm with your password',
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Delete everything'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Keep my account'),
          ),
        ],
      ),
    );
  }
}
