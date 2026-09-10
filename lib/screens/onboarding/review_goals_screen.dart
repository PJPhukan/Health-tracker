import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/profile_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';

/// Editable review of the auto-calculated targets. Every value is pre-filled
/// with the calculation and can be overridden before confirming.
///
/// Reused by onboarding (via [draftProfile]) and by "Edit goals" in Settings
/// (via [existingProfile]).
class ReviewGoalsScreen extends StatefulWidget {
  const ReviewGoalsScreen({super.key, this.draftProfile, this.existingProfile})
      : assert(draftProfile != null || existingProfile != null,
            'one profile source is required');

  final UserProfile? draftProfile;
  final UserProfile? existingProfile;

  bool get isEditing => existingProfile != null;

  @override
  State<ReviewGoalsScreen> createState() => _ReviewGoalsScreenState();
}

class _ReviewGoalsScreenState extends State<ReviewGoalsScreen> {
  late final UserProfile _profile =
      widget.existingProfile ?? widget.draftProfile!;

  late final _calories = TextEditingController();
  late final _protein = TextEditingController();
  late final _stepsMin = TextEditingController();
  late final _stepsMax = TextEditingController();
  late final _sleepMin = TextEditingController();
  late final _sleepMax = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = _profile.goals;
    _calories.text = '${g.calories}';
    _protein.text = '${g.proteinGrams}';
    _stepsMin.text = '${g.stepsMin}';
    _stepsMax.text = '${g.stepsMax}';
    _sleepMin.text = _trim(g.sleepMinHours);
    _sleepMax.text = _trim(g.sleepMaxHours);
  }

  @override
  void dispose() {
    for (final c in [
      _calories,
      _protein,
      _stepsMin,
      _stepsMax,
      _sleepMin,
      _sleepMax
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  HealthGoals? _readGoals() {
    final cal = int.tryParse(_calories.text.trim());
    final pro = int.tryParse(_protein.text.trim());
    final sMin = int.tryParse(_stepsMin.text.trim());
    final sMax = int.tryParse(_stepsMax.text.trim());
    final slMin = double.tryParse(_sleepMin.text.trim());
    final slMax = double.tryParse(_sleepMax.text.trim());

    if ([cal, pro, sMin, sMax].contains(null) ||
        slMin == null ||
        slMax == null) {
      return null;
    }
    if (cal! < 800 || cal > 6000) return null;
    if (pro! < 20 || pro > 400) return null;
    if (sMin! < 0 || sMax! < sMin || sMax > 40000) return null;
    if (slMin < 3 || slMax < slMin || slMax > 14) return null;

    return _profile.goals.copyWith(
      calories: cal,
      proteinGrams: pro,
      stepsMin: sMin,
      stepsMax: sMax,
      sleepMinHours: slMin,
      sleepMaxHours: slMax,
    );
  }

  Future<void> _confirm() async {
    final goals = _readGoals();
    if (goals == null) {
      setState(() => _error =
          'Some values look out of range — double-check calories, protein, '
          'steps and sleep.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final controller = context.read<ProfileController>();
    final bool synced;
    if (widget.isEditing) {
      synced = await controller.updateGoals(goals);
    } else {
      synced =
          await controller.completeOnboarding(_profile.copyWith(goals: goals));
    }

    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (widget.isEditing) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(synced ? 'Goals updated' : 'Goals saved on this device'),
      ));
    } else {
      // Onboarding done: clear the wizard + review routes so the AuthGate
      // (now rebuilt) shows MainShell with nothing stacked on top.
      navigator.popUntil((r) => r.isFirst);
      if (!synced && _profile.uid != 'local') {
        messenger.showSnackBar(const SnackBar(
          content: Text('Saved on this device — will sync when back online'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final g = _profile.goals;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          GradientHeader(
            title: widget.isEditing ? 'Edit your goals' : 'Your daily targets',
            subtitle: widget.isEditing
                ? 'Tune any number and save'
                : 'Calculated from your answers — adjust anything',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              children: [
                _RationaleCard(profile: _profile),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                _NumberField(
                  controller: _calories,
                  label: 'Daily calories',
                  unit: 'kcal',
                  icon: Icons.local_fire_department_rounded,
                ),
                _NumberField(
                  controller: _protein,
                  label: 'Protein',
                  unit: 'g',
                  icon: Icons.egg_alt_rounded,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _stepsMin,
                        label: 'Steps (min)',
                        unit: '',
                        icon: Icons.directions_walk_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _NumberField(
                        controller: _stepsMax,
                        label: 'Steps (max)',
                        unit: '',
                        icon: Icons.directions_run_rounded,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _sleepMin,
                        label: 'Sleep (min)',
                        unit: 'h',
                        icon: Icons.bedtime_rounded,
                        decimal: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _NumberField(
                        controller: _sleepMax,
                        label: 'Sleep (max)',
                        unit: 'h',
                        icon: Icons.bedtime_off_rounded,
                        decimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Starting point: ${g.calories} kcal · ${g.proteinGrams} g '
                  'protein · ${g.stepsMin}–${g.stepsMax} steps · '
                  '${_trim(g.sleepMinHours)}–${_trim(g.sleepMaxHours)} h sleep. '
                  'You can change these anytime in Profile.',
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
            child: BusyButton(
              label: widget.isEditing ? 'Save goals' : 'Looks good — start',
              busy: _saving,
              onPressed: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _RationaleCard extends StatelessWidget {
  const _RationaleCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F7F4), Color(0xFFF7F4EE)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.insights_rounded,
            color: AppColors.teal,
            size: 32,
            iconSize: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Based on ${profile.gender.label.toLowerCase()}, ${profile.age} yrs, '
              '${profile.heightCm.toStringAsFixed(0)} cm, '
              '${profile.currentWeightKg.toStringAsFixed(1)} kg, '
              '${profile.activityLevel.label.toLowerCase()}, aiming to '
              '${profile.primaryGoal.label.toLowerCase()}.',
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.icon,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData icon;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, size: 26, iconSize: 13),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: t.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              decimal
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              suffixText: unit.isEmpty ? null : unit,
            ),
          ),
        ],
      ),
    );
  }
}
