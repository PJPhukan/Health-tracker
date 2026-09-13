import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';
import '../../providers/auth_controller.dart';
import '../../providers/health_provider.dart';
import '../../providers/profile_controller.dart';
import '../../services/guest_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../main_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.isMotivated = false,
    this.initialIngredients,
    this.initialGoal,
    this.initialSuggestion,
  });

  final bool isMotivated;
  final List<String>? initialIngredients;
  final PrimaryGoal? initialGoal;
  final String? initialSuggestion;

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

  bool get _shouldMigrate =>
      widget.isMotivated ||
      GuestService.instance.isGuest ||
      widget.initialIngredients != null;

  Future<void> _handlePostSignupMigration() async {
    final auth = context.read<AuthController>();
    final health = context.read<HealthProvider>();
    final profileCtrl = context.read<ProfileController>();
    final guest = GuestService.instance;

    final ingredients =
        widget.initialIngredients ?? guest.quickStartIngredients;
    final goal =
        widget.initialGoal ?? guest.quickStartGoal ?? PrimaryGoal.maintain;
    final suggestion =
        widget.initialSuggestion ?? guest.quickStartSuggestion;

    if (ingredients.isNotEmpty) {
      await health.addPantryItemsBatch(ingredients);
    }
    if (suggestion != null && suggestion.isNotEmpty) {
      await health.seedInitialSuggestion(suggestion);
    }

    final defaultGoals = GuestService.defaultGoalsFor(goal);
    final user = auth.user;
    final draftProfile = UserProfile(
      uid: auth.profileId,
      email: user?.email,
      displayName:
          user?.displayName ?? user?.email?.split('@').first ?? 'Friend',
      age: 28,
      gender: Gender.other,
      heightCm: 170,
      currentWeightKg: 70,
      targetWeightKg: 70,
      activityLevel: ActivityLevel.light,
      primaryGoal: goal,
      goals: defaultGoals,
      onboardingComplete: true, // Skip 6-step wizard for now
      updatedAt: DateTime.now().toIso8601String(),
    );
    await profileCtrl.updateProfile(draftProfile);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('v4_pantry_onboarded_${auth.profileId}', true);

    await guest.markGuestConverted();
    await guest.setPendingProfilePrompt(true);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _notice = problem);
      return;
    }
    setState(() => _notice = null);
    FocusScope.of(context).unfocus();

    final ok = await context
        .read<AuthController>()
        .signUp(_email.text, _password.text);
    if (ok && mounted && _shouldMigrate) {
      await _handlePostSignupMigration();
    }
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    final ok = await context.read<AuthController>().signInWithGoogle();
    if (ok && mounted && _shouldMigrate) {
      await _handlePostSignupMigration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final message = auth.error ?? _notice;
    final isMotivated = widget.isMotivated || GuestService.instance.isGuest;

    return AuthScaffold(
      title: isMotivated
          ? 'Save your suggestion and start tracking'
          : 'Create your account',
      subtitle: isMotivated
          ? 'Free account — takes 30 seconds to keep your meals and pantry synced.'
          : 'A minute of setup, then your targets are personal.',
      children: [
        if (message != null) ...[
          ErrorBanner(message: message),
          const SizedBox(height: AppSpacing.md),
        ],
        // In motivated mode, Google Sign-In is the PRIMARY button at the top!
        if (isMotivated) ...[
          GoogleButton(
            label: 'Sign up with Google',
            onPressed: auth.busy ? null : _submitGoogle,
          ),
          const SizedBox(height: AppSpacing.md),
          const OrDivider(label: 'Or sign up with email'),
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
          label: isMotivated ? 'Sign up with email' : 'Create account',
          busy: auth.busy,
          onPressed: _submit,
        ),
        // In standard mode, Google button is below the divider
        if (!isMotivated) ...[
          const SizedBox(height: AppSpacing.md),
          const OrDivider(),
          const SizedBox(height: AppSpacing.md),
          GoogleButton(
            label: 'Sign up with Google',
            onPressed: auth.busy ? null : _submitGoogle,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
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
