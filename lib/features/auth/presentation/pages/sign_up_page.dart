import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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

    final error = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          fullName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: true,
      title: 'Create your account',
      subtitle:
          'Your account and all your academic data stay encrypted on this '
          'device.',
      children: <Widget>[
        AuthErrorBanner(message: _error),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LabeledField(
                  label: 'Full name',
                  controller: _nameController,
                  hint: 'Juan Dela Cruz',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const <String>[AutofillHints.name],
                  prefixIcon: Icons.person_outline_rounded,
                  maxLength: 80,
                  validator: Validators.name,
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'you@university.edu',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const <String>[AutofillHints.email],
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: Validators.email,
                ),
                const SizedBox(height: 18),
                PasswordField(
                  label: 'Password',
                  controller: _passwordController,
                  hint: 'At least ${Validators.minPasswordLength} characters',
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  validator: Validators.password,
                ),
                const SizedBox(height: 18),
                PasswordField(
                  label: 'Confirm password',
                  controller: _confirmController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 16),
                const _PasswordGuidance(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordGuidance extends StatelessWidget {
  const _PasswordGuidance();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Passwords are salted and hashed with PBKDF2 before they are '
              'stored. There is no password reset, so choose a long passphrase '
              'you will remember.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
