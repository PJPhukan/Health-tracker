import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';
import '../../providers/health_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/guest_service.dart';
import '../../theme/app_theme.dart';
import '../auth/signup_screen.dart';
import '../main_shell.dart';

/// 60-second first-run experience:
/// Screen 1: Kitchen Pantry Chips
/// Screen 2: Quick Goal Selection
/// Screen 3: Instant Gemini Meal Suggestion (Wow moment)
class QuickStartFlow extends StatefulWidget {
  const QuickStartFlow({super.key});

  @override
  State<QuickStartFlow> createState() => _QuickStartFlowState();
}

class _QuickStartFlowState extends State<QuickStartFlow> {
  final PageController _pageController = PageController();

  // Screen 1 state: selected ingredients
  final Set<String> _selectedIngredients = {};
  static const List<String> _defaultIngredients = [
    'Rice',
    'Dal',
    'Eggs',
    'Onion',
    'Tomato',
    'Potato',
    'Milk',
    'Bread',
    'Chicken',
    'Banana',
    'Curd',
    'Ghee',
  ];
  final List<String> _customIngredients = [];
  final TextEditingController _customController = TextEditingController();
  bool _isAddingCustom = false;

  // Screen 2 state: goal
  PrimaryGoal? _selectedGoal;

  // Screen 3 state: Gemini suggestion
  bool _isLoadingSuggestion = false;
  String? _suggestionText;
  String? _suggestionError;
  final GeminiService _gemini = GeminiService();

  @override
  void dispose() {
    _pageController.dispose();
    _customController.dispose();
    super.dispose();
  }

  String _currentMealTime() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return 'breakfast';
    if (h >= 11 && h < 16) return 'lunch';
    if (h >= 16 && h < 22) return 'dinner';
    return 'snack';
  }

  void _addCustomItem() {
    final val = _customController.text.trim();
    if (val.isNotEmpty) {
      // Capitalize first letter
      final formatted = val[0].toUpperCase() + val.substring(1);
      setState(() {
        if (!_customIngredients.contains(formatted) &&
            !_defaultIngredients.contains(formatted)) {
          _customIngredients.add(formatted);
        }
        _selectedIngredients.add(formatted);
        _customController.clear();
        _isAddingCustom = false;
      });
    }
  }

  void _onGoalSelected(PrimaryGoal goal) {
    setState(() {
      _selectedGoal = goal;
    });
    _pageController.animateToPage(
      2,
      duration: AppAnimations.shortDuration,
      curve: Curves.easeOutCubic,
    );
    _fetchSuggestion(goal);
  }

  Future<void> _fetchSuggestion(PrimaryGoal goal) async {
    setState(() {
      _isLoadingSuggestion = true;
      _suggestionError = null;
      _suggestionText = null;
    });

    try {
      final goalDescription = switch (goal) {
        PrimaryGoal.buildMuscle => 'Build muscle with high protein',
        PrimaryGoal.gainWeight => 'Gain healthy weight',
        PrimaryGoal.loseWeight => 'Lose weight & cut calories',
        PrimaryGoal.maintain => 'Stay healthy and energized',
      };

      final text = await _gemini.getQuickStartSuggestion(
        ingredients: _selectedIngredients.toList(),
        goal: goalDescription,
        mealTime: _currentMealTime(),
      );

      if (!mounted) return;
      setState(() {
        _suggestionText = text;
        _isLoadingSuggestion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suggestionError = "Couldn't generate suggestion. Tap to try again.";
        _isLoadingSuggestion = false;
      });
    }
  }

  Future<void> _handleSkipForNow() async {
    if (_selectedGoal == null || _suggestionText == null) return;

    final ingredients = _selectedIngredients.toList();
    final goal = _selectedGoal!;
    final suggestion = _suggestionText!;

    final guest = GuestService.instance;
    await guest.startGuestMode(
      ingredients: ingredients,
      goal: goal,
      suggestion: suggestion,
    );

    if (!mounted) return;
    final health = context.read<HealthProvider>();
    await health.addPantryItemsBatch(ingredients);
    await health.seedInitialSuggestion(suggestion);
    health.syncGoals(GuestService.defaultGoalsFor(goal));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('v4_pantry_onboarded_local', true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _handleSaveThis() {
    if (_selectedGoal == null || _suggestionText == null) return;

    GuestService.instance.cacheQuickStartData(
      ingredients: _selectedIngredients.toList(),
      goal: _selectedGoal!,
      suggestion: _suggestionText!,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(
          isMotivated: true,
          initialIngredients: _selectedIngredients.toList(),
          initialGoal: _selectedGoal!,
          initialSuggestion: _suggestionText!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildScreen1Kitchen(),
              _buildScreen2Goal(),
              _buildScreen3Suggestion(),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 1: QUICK START KITCHEN
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildScreen1Kitchen() {
    final t = Theme.of(context).textTheme;
    final canProceed = _selectedIngredients.length >= 2;
    final allIngredients = [..._defaultIngredients, ..._customIngredients];

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        // App logo centered top
        Center(
          child: Image.asset(
            'assets/branding/logo.png',
            width: 64,
            height: 64,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Stock Plate',
          style: t.labelLarge?.copyWith(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Text(
                "What's in your kitchen right now?",
                style: t.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Tap what you have — we will find your meal in seconds',
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 12 Common items wrap layout
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: allIngredients.map((item) {
                    final selected = _selectedIngredients.contains(item);
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedIngredients.remove(item);
                          } else {
                            _selectedIngredients.add(item);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.onTrackSoft : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? AppColors.onTrack : AppColors.divider,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: selected
                                  ? AppColors.onTrack.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.onTrack,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              item,
                              style: t.titleMedium?.copyWith(
                                color: selected
                                    ? AppColors.onTrack
                                    : AppColors.textPrimary,
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Add custom ingredient row
                if (!_isAddingCustom)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _isAddingCustom = true),
                      icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.teal),
                      label: Text(
                        '+ Add something else',
                        style: t.labelLarge?.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'e.g. Oats, Spinach...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.divider),
                              ),
                            ),
                            onSubmitted: (_) => _addCustomItem(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton.filled(
                          onPressed: _addCustomItem,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.teal,
                          ),
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _customController.clear();
                            _isAddingCustom = false;
                          }),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Bottom Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              Text(
                _selectedIngredients.length < 2
                    ? 'Select at least 2 ingredients to continue'
                    : '${_selectedIngredients.length} ingredients selected',
                style: t.bodySmall?.copyWith(
                  color: canProceed
                      ? AppColors.onTrack
                      : AppColors.textSecondary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canProceed
                      ? () {
                          _pageController.animateToPage(
                            1,
                            duration: AppAnimations.shortDuration,
                            curve: Curves.easeOutCubic,
                          );
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Next →',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 2: QUICK GOAL
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildScreen2Goal() {
    final t = Theme.of(context).textTheme;

    final goals = [
      (
        goal: PrimaryGoal.buildMuscle,
        emoji: '💪',
        title: 'Build muscle',
        subtitle: 'High protein focus with modest surplus',
      ),
      (
        goal: PrimaryGoal.gainWeight,
        emoji: '⬆️',
        title: 'Gain weight',
        subtitle: 'Calorie surplus to steadily build mass',
      ),
      (
        goal: PrimaryGoal.loseWeight,
        emoji: '⬇️',
        title: 'Lose weight',
        subtitle: 'Calorie deficit while protecting muscle',
      ),
      (
        goal: PrimaryGoal.maintain,
        emoji: '✅',
        title: 'Stay healthy',
        subtitle: 'Clean balanced maintenance nutrition',
      ),
    ];

    return Column(
      children: [
        // Back navigation
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _pageController.animateToPage(
                0,
                duration: AppAnimations.shortDuration,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              Text(
                "What's your main goal?",
                style: t.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'We tailor calorie and protein targets to this choice.',
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ListView.separated(
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = goals[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _onGoalSelected(item.goal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle,
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 3: INSTANT SUGGESTION (THE WOW MOMENT)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildScreen3Suggestion() {
    final t = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Image.asset(
            'assets/branding/logo.png',
            width: 54,
            height: 54,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Instant Kitchen Match',
          style: t.labelLarge?.copyWith(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: _isLoadingSuggestion
              ? const _PulsingLoadingState()
              : _suggestionError != null
                  ? _buildSuggestionError()
                  : _buildSuggestionLoaded(),
        ),
      ],
    );
  }

  Widget _buildSuggestionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, size: 48, color: AppColors.behind),
            const SizedBox(height: AppSpacing.md),
            Text(
              _suggestionError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => _fetchSuggestion(_selectedGoal ?? PrimaryGoal.maintain),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionLoaded() {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Wow Suggestion Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.tealLight.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.onTrackSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.onTrack,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Ready to make right now',
                        style: t.labelLarge?.copyWith(
                          color: AppColors.onTrack,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _suggestionText ?? '',
                  style: t.bodyLarge?.copyWith(
                    height: 1.6,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Large primary CTA: "Save this & track your progress →"
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _handleSaveThis,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Save this & track your progress →',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Small subtext
          Text(
            'Free account — takes 30 seconds',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Secondary link: "Just browsing? Skip for now →"
          Center(
            child: TextButton(
              onPressed: _handleSkipForNow,
              child: Text(
                'Just browsing? Skip for now →',
                style: t.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing logo animation with text during Gemini generation
class _PulsingLoadingState extends StatefulWidget {
  const _PulsingLoadingState();

  @override
  State<_PulsingLoadingState> createState() => _PulsingLoadingStateState();
}

class _PulsingLoadingStateState extends State<_PulsingLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final scale = 0.94 + 0.12 * _anim.value;
              final glowAlpha = 0.15 + 0.25 * _anim.value;
              return Container(
                width: 110,
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealLight.withValues(alpha: glowAlpha),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/branding/logo.png',
                    width: 76,
                    height: 76,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Finding your perfect meal...',
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Matching your pantry items to your goal',
            style: t.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
