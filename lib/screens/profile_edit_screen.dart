import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../providers/profile_controller.dart';
import '../services/goal_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';
import 'onboarding/onboarding_widgets.dart';
import 'onboarding/review_goals_screen.dart';

/// Edit the profile inputs (name, body stats, activity, goal). Saving jumps to
/// the review screen with freshly recalculated targets, so the user confirms
/// the new numbers the same way they did during onboarding.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  late int _age = widget.profile.age;
  late Gender _gender = widget.profile.gender;
  late double _height = widget.profile.heightCm;
  late double _current = widget.profile.currentWeightKg;
  late double _target = widget.profile.targetWeightKg;
  late ActivityLevel _activity = widget.profile.activityLevel;
  late PrimaryGoal _goal = widget.profile.primaryGoal;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    final recalculated = GoalCalculator.fromInputs(
      gender: _gender,
      age: _age,
      heightCm: _height,
      currentWeightKg: _current,
      activity: _activity,
      goal: _goal,
    );
    final updated = widget.profile.copyWith(
      displayName: _name.text.trim(),
      age: _age,
      gender: _gender,
      heightCm: _height,
      currentWeightKg: _current,
      targetWeightKg: _target,
      activityLevel: _activity,
      primaryGoal: _goal,
      goals: recalculated,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReviewGoalsScreen(existingProfile: updated),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Edit profile',
            subtitle: 'Update and we’ll recalculate your targets',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              children: [
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AuthField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Your name',
                ),
                const SizedBox(height: AppSpacing.md),
                StepperField(
                  label: 'Age',
                  value: '$_age',
                  unit: 'years',
                  onMinus: () =>
                      setState(() => _age = (_age - 1).clamp(13, 100)),
                  onPlus: () =>
                      setState(() => _age = (_age + 1).clamp(13, 100)),
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Gender'),
                const SizedBox(height: AppSpacing.xs),
                ChoiceGrid<Gender>(
                  values: Gender.values,
                  selected: _gender,
                  labelOf: (g) => g.label,
                  onChanged: (g) => setState(() => _gender = g),
                ),
                const SizedBox(height: AppSpacing.md),
                StepperField(
                  label: 'Height',
                  value: _height.toStringAsFixed(0),
                  unit: 'cm',
                  onMinus: () =>
                      setState(() => _height = (_height - 1).clamp(120, 230)),
                  onPlus: () =>
                      setState(() => _height = (_height + 1).clamp(120, 230)),
                ),
                const SizedBox(height: AppSpacing.md),
                StepperField(
                  label: 'Current weight',
                  value: _current.toStringAsFixed(1),
                  unit: 'kg',
                  onMinus: () => setState(
                      () => _current = (_current - 0.5).clamp(30, 250)),
                  onPlus: () => setState(
                      () => _current = (_current + 0.5).clamp(30, 250)),
                ),
                const SizedBox(height: AppSpacing.md),
                StepperField(
                  label: 'Target weight',
                  value: _target.toStringAsFixed(1),
                  unit: 'kg',
                  onMinus: () => setState(
                      () => _target = (_target - 0.5).clamp(30, 250)),
                  onPlus: () => setState(
                      () => _target = (_target + 0.5).clamp(30, 250)),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Activity level'),
                const SizedBox(height: AppSpacing.xs),
                OptionList<ActivityLevel>(
                  values: ActivityLevel.values,
                  selected: _activity,
                  titleOf: (a) => a.label,
                  subtitleOf: (a) => a.description,
                  onChanged: (a) => setState(() => _activity = a),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Primary goal'),
                const SizedBox(height: AppSpacing.xs),
                OptionList<PrimaryGoal>(
                  values: PrimaryGoal.values,
                  selected: _goal,
                  titleOf: (g) => g.label,
                  subtitleOf: (g) => g.description,
                  onChanged: (g) => setState(() => _goal = g),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Review new targets'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper the Settings screen uses to know if a profile exists.
extension ProfilePresence on ProfileController {
  bool get hasProfile => profile != null;
}
