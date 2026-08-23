import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Shown when a stored session exists but app lock is switched on.
///
/// Offers biometrics first and falls back to the account password, so the user
/// is never permanently shut out if the sensor fails.
class AppLockPage extends ConsumerStatefulWidget {
  const AppLockPage({super.key});

  @override
  ConsumerState<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends ConsumerState<AppLockPage> {
  final _passwordController = TextEditingController();

  bool _busy = false;
  bool _showPasswordFallback = false;
  String? _message;
  String _biometricLabel = 'Biometric unlock';

  @override
  void initState() {
    super.initState();
    // Prompt as soon as the screen settles so unlocking is a single tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBiometricLabel();
      _promptBiometrics();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricLabel() async {
    final label = await ref.read(biometricServiceProvider).describeAvailable();
    if (mounted) setState(() => _biometricLabel = label);
  }

  Future<void> _promptBiometrics() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final result = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometrics();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _showPasswordFallback =
          _showPasswordFallback || result != BiometricResult.success;
      _message = switch (result) {
        BiometricResult.success => null,
        BiometricResult.cancelled => null,
        BiometricResult.unavailable =>
          'Biometrics are unavailable on this device. Use your password.',
        BiometricResult.notEnrolled =>
          'No biometrics are enrolled. Use your password instead.',
        BiometricResult.failed => 'We could not verify you. Please try again.',
      };
    });
  }

  Future<void> _submitPassword() async {
    if (_busy) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _message = 'Please enter your password.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });

    final error = await ref
        .read(authControllerProvider.notifier)
        .unlockWithPassword(_passwordController.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return AuthScaffold(
      title: 'Welcome back${user == null ? '' : ', ${user.firstName}'}',
      subtitle: 'StudySync is locked. Verify it is you to continue.',
      footer: TextButton.icon(
        onPressed: _busy
            ? null
            : () => ref.read(authControllerProvider.notifier).signOut(),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Sign in with a different account'),
      ),
      children: <Widget>[
        AuthErrorBanner(message: _message),
        FilledButton.icon(
          onPressed: _busy ? null : _promptBiometrics,
          icon: const Icon(Icons.fingerprint_rounded),
          label: Text(_biometricLabel),
        ),
        if (_showPasswordFallback) ...<Widget>[
          const SizedBox(height: 28),
          Row(
            children: <Widget>[
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or use your password',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          PasswordField(
            label: 'Password',
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _busy ? null : _submitPassword,
            child: const Text('Unlock'),
          ),
        ],
      ],
    );
  }
}

/// Plain splash shown while the stored session is being restored.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.sync_alt_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
