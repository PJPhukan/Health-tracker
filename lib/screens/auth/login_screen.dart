import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_email.text.trim().isEmpty) return 'Enter your email address.';
    if (!_email.text.contains('@')) return 'That email address doesn’t look right.';
    if (_password.text.isEmpty) return 'Enter your password.';
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
    // The auth gate swaps this screen out on success; nothing to do here.
    await context.read<AuthController>().signIn(_email.text, _password.text);
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _notice = 'Enter your email above, then tap “Forgot password”.');
      return;
    }
    setState(() => _notice = null);
    final sent =
        await context.read<AuthController>().sendPasswordReset(_email.text);
    if (sent && mounted) {
      setState(() => _notice = 'Password reset link sent to ${_email.text.trim()}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final message = auth.error ?? _notice;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to pick up where you left off.',
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
          hint: 'Your password',
          obscure: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          autofillHints: const [AutofillHints.password],
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: auth.busy ? null : _forgotPassword,
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        BusyButton(label: 'Sign in', busy: auth.busy, onPressed: _submit),
        const SizedBox(height: AppSpacing.md),
        const OrDivider(),
        const SizedBox(height: AppSpacing.md),
        GoogleButton(
          onPressed: auth.busy
              ? null
              : () => context.read<AuthController>().signInWithGoogle(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here?',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
            TextButton(
              onPressed: auth.busy
                  ? null
                  : () {
                      context.read<AuthController>().clearError();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SignupScreen()));
                    },
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}
