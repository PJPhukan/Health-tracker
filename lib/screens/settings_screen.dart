import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
    await context.read<AuthController>().signOut();
    // The auth gate rebuilds into the Login screen; just close Settings.
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Profile',
            subtitle: 'Your account and targets',
            trailing: AnimatedSparkleIcon(
                icon: Icons.person_rounded, size: 24),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xl),
              children: [
                const MetaLabel('Account'),
                const SizedBox(height: AppSpacing.xs),
                _AccountCard(auth: auth),
                const SizedBox(height: AppSpacing.lg),
                if (auth.stage == AuthStage.signedIn) ...[
                  OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
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
