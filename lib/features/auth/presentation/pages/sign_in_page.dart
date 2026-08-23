import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
    // On success the router redirect moves to the dashboard automatically.
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle:
          'Sign in to pick up your schedule, deadlines and group work where '
          'you left off.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('New to StudySync?'),
          TextButton(
            onPressed: _submitting
                ? null
                : () => context.push(AppRoute.signUp.path),
            child: const Text('Create an account'),
          ),
        ],
      ),
      children: <Widget>[
        AuthErrorBanner(message: _error),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  // Only the format is enforced here; whether it is correct is
                  // decided by the repository.
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Please enter your password.'
                      : null,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
