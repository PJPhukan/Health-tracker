import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_email.text.trim().isEmpty) return 'Enter your email address.';
    if (!_email.text.contains('@')) {
      return 'That email address doesn’t look right.';
    }
    if (_password.text.length < 6) {
      return 'Choose a password with at least 6 characters.';
    }
    if (_password.text != _confirm.text) return 'The passwords don’t match.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _notice = problem);
      return;
    }
    setState(() => _notice = null);
    FocusScope.of(context).unfocus();
    // On success the auth gate replaces this route with onboarding.
    await context.read<AuthController>().signUp(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final message = auth.error ?? _notice;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'A minute of setup, then your targets are personal.',
      children: [
        if (message != null) ...[
          ErrorBanner(message: message),
          const SizedBox(height: AppSpacing.md),
        ],
        AuthField(
          controller: _email,
          label: 'Email',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: AppSpacing.md),
        AuthField(
          controller: _password,
          label: 'Password',
          hint: 'At least 6 characters',
          obscure: _obscure,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          trailing: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthField(
          controller: _confirm,
          label: 'Confirm password',
          hint: 'Type it once more',
          obscure: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
        ),
        const SizedBox(height: AppSpacing.lg),
        BusyButton(
            label: 'Create account', busy: auth.busy, onPressed: _submit),
        const SizedBox(height: AppSpacing.md),
        const OrDivider(),
        const SizedBox(height: AppSpacing.md),
        GoogleButton(
          label: 'Sign up with Google',
          onPressed: auth.busy
              ? null
              : () => context.read<AuthController>().signInWithGoogle(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account?',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
            TextButton(
              onPressed: auth.busy
                  ? null
                  : () {
                      context.read<AuthController>().clearError();
                      Navigator.of(context).pop();
                    },
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
