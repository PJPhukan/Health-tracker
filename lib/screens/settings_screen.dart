import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/auth_controller.dart';
import '../providers/health_provider.dart';
import '../providers/profile_controller.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'meal_routine_screen.dart';
import 'onboarding/pantry_onboarding_screen.dart';
import 'onboarding/review_goals_screen.dart';
import 'profile_edit_screen.dart';
import 'subscription_screen.dart';

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
                const MetaLabel('Subscription'),
                const SizedBox(height: AppSpacing.xs),
                const _SubscriptionCard(),
                const SizedBox(height: AppSpacing.lg),
                const MetaLabel('Reminders'),
                const SizedBox(height: AppSpacing.xs),
                const _RemindersCard(),
                const SizedBox(height: AppSpacing.lg),
                const MetaLabel('Pantry'),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PantryOnboardingScreen()),
                  ),
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text('Rebuild pantry checklist'),
                ),
                const SizedBox(height: AppSpacing.lg),
                const MetaLabel('Routine'),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MealRoutineScreen()),
                  ),
                  icon: const Icon(Icons.repeat_rounded, size: 18),
                  label: const Text('My meal routine'),
                ),
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();
    final t = Theme.of(context).textTheme;
    final premium = sub.isPremium;

    return SoftCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBadge(
            icon: premium
                ? Icons.workspace_premium_rounded
                : Icons.auto_awesome_rounded,
            color: premium ? AppColors.onTrack : AppColors.accent,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Plate Premium', style: t.titleMedium),
                Text(
                  'Remove ads · Unlimited access',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            premium ? 'Manage subscription' : 'Upgrade',
            style: t.labelLarge?.copyWith(
                color: AppColors.teal, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RemindersCard extends StatefulWidget {
  const _RemindersCard();

  @override
  State<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<_RemindersCard> {
  NotificationPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await NotificationService.instance.loadPrefs();
    if (mounted) setState(() => _prefs = prefs);
  }

  Future<void> _refreshSchedule() async {
    if (!mounted) return;
    await context.read<HealthProvider>().refreshReminders();
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _prefs = _prefs?.copyWith(enabled: value));
    await NotificationService.instance.setEnabled(value);
    if (value) await NotificationService.instance.requestPermission();
    await _refreshSchedule();
  }

  Future<void> _pickTime(ReminderSlot slot) async {
    final current = _prefs?.forSlot(slot);
    if (current == null) return;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() => _prefs = switch (slot) {
          ReminderSlot.morning => _prefs?.copyWith(morning: picked),
          ReminderSlot.lunch => _prefs?.copyWith(lunch: picked),
          ReminderSlot.evening => _prefs?.copyWith(evening: picked),
        });
    await NotificationService.instance.setTime(slot, picked);
    await _refreshSchedule();
  }

  String _label(ReminderSlot slot) => switch (slot) {
        ReminderSlot.morning => 'Morning — log breakfast',
        ReminderSlot.lunch => 'Lunch — pantry suggestion',
        ReminderSlot.evening => 'Evening check-in',
      };

  IconData _icon(ReminderSlot slot) => switch (slot) {
        ReminderSlot.morning => Icons.wb_sunny_rounded,
        ReminderSlot.lunch => Icons.restaurant_rounded,
        ReminderSlot.evening => Icons.nightlight_round,
      };

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    final t = Theme.of(context).textTheme;
    if (prefs == null) {
      return const SoftCard(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          height: 24,
          child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Daily reminders', style: t.titleMedium),
              ),
              Switch(value: prefs.enabled, onChanged: _setEnabled),
            ],
          ),
          Text(
            'Suppressed automatically once you’ve already logged '
            'breakfast or fetched a suggestion that day.',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (prefs.enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            for (final slot in ReminderSlot.values)
              _TimeRow(
                icon: _icon(slot),
                label: _label(slot),
                time: prefs.forSlot(slot),
                onTap: () => _pickTime(slot),
              ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => NotificationService.instance.showTest(),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Send a test notification'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            IconBadge(icon: icon, size: 32, iconSize: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: t.bodyMedium)),
            Text(time.format(context),
                style: t.titleMedium?.copyWith(color: AppColors.teal)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
