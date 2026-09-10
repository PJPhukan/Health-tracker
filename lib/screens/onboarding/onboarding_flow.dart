import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/auth_controller.dart';
import '../../services/goal_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import 'onboarding_widgets.dart';
import 'review_goals_screen.dart';

/// Mutable answers, carried across the wizard steps.
class OnboardingDraft {
  String name = '';
  int age = 28;
  Gender gender = Gender.other;
  double heightCm = 170;
  double currentWeightKg = 70;
  double targetWeightKg = 70;
  ActivityLevel activity = ActivityLevel.light;
  PrimaryGoal goal = PrimaryGoal.maintain;

  HealthGoals calculate() => GoalCalculator.fromInputs(
        gender: gender,
        age: age,
        heightCm: heightCm,
        currentWeightKg: currentWeightKg,
        activity: activity,
        goal: goal,
      );

  UserProfile toProfile({required String uid, String? email}) => UserProfile(
        uid: uid,
        email: email,
        displayName: name.trim(),
        age: age,
        gender: gender,
        heightCm: heightCm,
        currentWeightKg: currentWeightKg,
        targetWeightKg: targetWeightKg,
        activityLevel: activity,
        primaryGoal: goal,
        goals: calculate(),
        onboardingComplete: false,
        updatedAt: DateTime.now().toIso8601String(),
      );
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _draft = OnboardingDraft();
  final _controller = PageController();
  final _nameField = TextEditingController();
  int _page = 0;
  late final List<_Step> _steps = _buildSteps();

  @override
  void initState() {
    super.initState();
    // Seed the name from the Firebase display name / email if we have one.
    final user = context.read<AuthController>().user;
    final seed = user?.displayName?.trim();
    if (seed != null && seed.isNotEmpty) {
      _draft.name = seed;
    } else if (user?.email != null) {
      _draft.name = user!.email!.split('@').first;
    }
    _nameField.text = _draft.name;
    // Keep the draft (and the Continue button's enabled state) in sync as the
    // user types their name.
    _nameField.addListener(() {
      if (_draft.name == _nameField.text) return;
      setState(() => _draft.name = _nameField.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameField.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _steps.length - 1) {
      _goToReview();
      return;
    }
    FocusScope.of(context).unfocus();
    _controller.nextPage(
        duration: AppAnimations.shortDuration, curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_page == 0) return;
    FocusScope.of(context).unfocus();
    _controller.previousPage(
        duration: AppAnimations.shortDuration, curve: Curves.easeOutCubic);
  }

  Future<void> _goToReview() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthController>();
    final draftProfile = _draft.toProfile(
      uid: auth.profileId,
      email: auth.user?.email,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewGoalsScreen(draftProfile: draftProfile),
      ),
    );
    // If onboarding completed on the review screen, the AuthGate rebuilds and
    // this flow is gone. If the user backed out, they land here to adjust.
  }

  List<_Step> _buildSteps() => [
        _Step(
          title: 'What should we call you?',
          subtitle: 'Just a first name is fine.',
          canAdvance: () => _draft.name.trim().isNotEmpty,
          builder: (setLocal) => AuthField(
            controller: _nameField,
            label: 'Name',
            hint: 'e.g. Parag',
            textInputAction: TextInputAction.next,
            onSubmitted: _next,
            autofillHints: const [AutofillHints.givenName],
          ),
        ),
        _Step(
          title: 'A bit about you',
          subtitle: 'Used to estimate your energy needs.',
          canAdvance: () => _draft.age >= 13 && _draft.age <= 100,
          builder: (setLocal) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepperField(
                label: 'Age',
                value: '${_draft.age}',
                unit: 'years',
                onMinus: () => setLocal(() => _draft.age =
                    (_draft.age - 1).clamp(13, 100)),
                onPlus: () => setLocal(() => _draft.age =
                    (_draft.age + 1).clamp(13, 100)),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionLabel('Gender'),
              const SizedBox(height: AppSpacing.xs),
              ChoiceGrid<Gender>(
                values: Gender.values,
                selected: _draft.gender,
                labelOf: (g) => g.label,
                onChanged: (g) => setLocal(() => _draft.gender = g),
              ),
            ],
          ),
        ),
        _Step(
          title: 'Your measurements',
          subtitle: 'Height and weight in metric.',
          canAdvance: () =>
              _draft.heightCm >= 120 &&
              _draft.heightCm <= 230 &&
              _draft.currentWeightKg >= 30 &&
              _draft.currentWeightKg <= 250 &&
              _draft.targetWeightKg >= 30 &&
              _draft.targetWeightKg <= 250,
          builder: (setLocal) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepperField(
                label: 'Height',
                value: _draft.heightCm.toStringAsFixed(0),
                unit: 'cm',
                onMinus: () => setLocal(() => _draft.heightCm =
                    (_draft.heightCm - 1).clamp(120, 230)),
                onPlus: () => setLocal(() => _draft.heightCm =
                    (_draft.heightCm + 1).clamp(120, 230)),
              ),
              const SizedBox(height: AppSpacing.md),
              StepperField(
                label: 'Current weight',
                value: _draft.currentWeightKg.toStringAsFixed(1),
                unit: 'kg',
                onMinus: () => setLocal(() {
                  _draft.currentWeightKg =
                      (_draft.currentWeightKg - 0.5).clamp(30, 250);
                }),
                onPlus: () => setLocal(() {
                  _draft.currentWeightKg =
                      (_draft.currentWeightKg + 0.5).clamp(30, 250);
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              StepperField(
                label: 'Target weight',
                value: _draft.targetWeightKg.toStringAsFixed(1),
                unit: 'kg',
                onMinus: () => setLocal(() {
                  _draft.targetWeightKg =
                      (_draft.targetWeightKg - 0.5).clamp(30, 250);
                }),
                onPlus: () => setLocal(() {
                  _draft.targetWeightKg =
                      (_draft.targetWeightKg + 0.5).clamp(30, 250);
                }),
              ),
            ],
          ),
        ),
        _Step(
          title: 'How active are you?',
          subtitle: 'Outside of deliberate workouts.',
          canAdvance: () => true,
          builder: (setLocal) => OptionList<ActivityLevel>(
            values: ActivityLevel.values,
            selected: _draft.activity,
            titleOf: (a) => a.label,
            subtitleOf: (a) => a.description,
            onChanged: (a) => setLocal(() => _draft.activity = a),
          ),
        ),
        _Step(
          title: "What's your main goal?",
          subtitle: 'We tune calories and protein around this.',
          canAdvance: () => true,
          builder: (setLocal) => OptionList<PrimaryGoal>(
            values: PrimaryGoal.values,
            selected: _draft.goal,
            titleOf: (g) => g.label,
            subtitleOf: (g) => g.description,
            onChanged: (g) => setLocal(() => _draft.goal = g),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_page];
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(value: (_page + 1) / (_steps.length + 1)),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _steps.length,
                itemBuilder: (context, i) => _StepView(
                  step: _steps[i],
                  // Re-run this step's builder on local edits + refresh the
                  // Continue button's enabled state.
                  onLocalChange: () => setState(() {
                    _draft.name = _nameField.text;
                  }),
                ),
              ),
            ),
            _NavBar(
              onBack: _page == 0 ? null : _back,
              onNext: step.canAdvance() ? _next : null,
              nextLabel:
                  _page == _steps.length - 1 ? 'Review targets' : 'Continue',
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  _Step({
    required this.title,
    required this.subtitle,
    required this.builder,
    required this.canAdvance,
  });

  final String title;
  final String subtitle;
  final Widget Function(void Function(VoidCallback) setLocal) builder;
  final bool Function() canAdvance;
}

class _StepView extends StatefulWidget {
  const _StepView({required this.step, required this.onLocalChange});
  final _Step step;
  final VoidCallback onLocalChange;

  @override
  State<_StepView> createState() => _StepViewState();
}

class _StepViewState extends State<_StepView> {
  void _setLocal(VoidCallback fn) {
    setState(fn);
    widget.onLocalChange();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.step.title, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(widget.step.subtitle,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          widget.step.builder(_setLocal),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: AppAnimations.shortDuration,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            valueColor: const AlwaysStoppedAnimation(AppColors.teal),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Row(
        children: [
          if (onBack != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: onNext,
              child: Text(nextLabel),
            ),
          ),
        ],
      ),
    );
  }
}
