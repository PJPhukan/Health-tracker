import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/auth_controller.dart';
import '../providers/profile_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'onboarding/review_goals_screen.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your logged meals, workouts and pantry stay on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (leave != true || !context.mounted) return;
    context.read<ProfileController>().resetForSignOut();
    await context.read<AuthController>().signOut();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profileCtrl = context.watch<ProfileController>();
    final profile = profileCtrl.profile;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Profile',
            subtitle: 'Your account and targets',
            trailing:
                AnimatedSparkleIcon(icon: Icons.person_rounded, size: 24),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xl),
              children: [
                const MetaLabel('Account'),
                const SizedBox(height: AppSpacing.xs),
                _AccountCard(auth: auth),
                if (profileCtrl.offline) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Showing your last saved profile (offline)',
                          style: t.labelSmall),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const MetaLabel('Daily targets'),
                const SizedBox(height: AppSpacing.xs),
                _GoalsCard(
                  goals: profileCtrl.goals,
                  onAdjust: profile == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ReviewGoalsScreen(existingProfile: profile),
                          )),
                ),
                if (profile != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ProfileDetailsCard(profile: profile),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(profile: profile),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit profile details'),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (auth.stage == AuthStage.signedIn)
                  OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Health logs are stored on this device. Cloud sync for meals, '
                  'workouts and pantry is planned for a later release.',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final signedIn = auth.stage == AuthStage.signedIn;
    final email = auth.user?.email ?? 'Not signed in';

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: signedIn
                    ? Icons.verified_user_rounded
                    : Icons.cloud_off_rounded,
                color: signedIn ? AppColors.onTrack : AppColors.textSecondary,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(signedIn ? email : 'Local-only mode',
                        style: t.titleMedium),
                    Text(
                      signedIn
                          ? 'Signed in'
                          : 'Accounts are unavailable right now',
                      style: t.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!auth.firebaseAvailable && auth.firebaseError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              auth.firebaseError!,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals, required this.onAdjust});
  final HealthGoals goals;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String h(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Calories', '${goals.calories} kcal'),
          _row('Protein', '${goals.proteinGrams} g'),
          _row('Steps', '${goals.stepsMin}–${goals.stepsMax}'),
          _row('Sleep',
              '${h(goals.sleepMinHours)}–${h(goals.sleepMaxHours)} h'),
          if (onAdjust != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdjust,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Adjust goals'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Complete onboarding to personalize these.',
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.displayName.isEmpty ? 'You' : profile.displayName,
              style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${profile.age} yrs · ${profile.gender.label} · '
            '${profile.heightCm.toStringAsFixed(0)} cm · '
            '${profile.currentWeightKg.toStringAsFixed(1)} kg '
            '(target ${profile.targetWeightKg.toStringAsFixed(1)})',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '${profile.activityLevel.label} · ${profile.primaryGoal.label}',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
