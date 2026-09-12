import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/user_profile.dart';
import '../providers/health_provider.dart';
import '../providers/profile_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/common.dart';
import '../widgets/summary_widgets.dart';
import 'log_entry_screen.dart';
import 'settings_screen.dart';
import 'suggestion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppAnimations.entranceDuration,
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Which meal slot "now" belongs to, for matching a routine — null outside
  /// meal hours so the banner doesn't linger all day.
  MealType? _currentMealSlot() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) return MealType.breakfast;
    if (h >= 11 && h < 16) return MealType.lunch;
    if (h >= 16 && h < 22) return MealType.dinner;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final summary = provider.today;
    final goals = context.watch<ProfileController>().goals;

    return Scaffold(
      floatingActionButton: _GlowFab(
        onPressed: () {
          context.read<HealthProvider>().getSuggestion();
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SuggestionScreen()));
        },
      ),
      body: Column(
        children: [
          // Fixed gradient header — stays put while the content scrolls.
          _HomeHeader(greeting: _greeting()),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.teal,
              onRefresh: provider.loadToday,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (provider.loading && summary == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 64),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.teal),
                            ),
                          )
                        else if (summary != null) ...[
                          if (_currentMealSlot() case final slot?)
                            if (provider.routineSuggestionFor(slot)
                                case final template?) ...[
                              StaggeredEntrance(
                                animation: _entrance,
                                index: 0,
                                child: _RoutineBanner(
                                    slot: slot, template: template),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          StaggeredEntrance(
                            animation: _entrance,
                            index: 1,
                            child: DailySummaryCard(
                                summary: summary, goals: goals),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          StaggeredEntrance(
                            animation: _entrance,
                            index: 2,
                            child: _GoalNote(goals: goals),
                          ),
                          if (summary.meals.isNotEmpty ||
                              summary.workouts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            StaggeredEntrance(
                              animation: _entrance,
                              index: 3,
                              child: RecentActivityCard(summary: summary),
                            ),
                          ],
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BannerAdSlot(),
        ],
      ),
    );
  }
}

// ─── HOME HEADER ────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: t.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: t.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Doubles as the way into Profile / Settings.
              Semantics(
                button: true,
                label: 'Profile and settings',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── GLOW FAB ───────────────────────────────────────────────────────────────

class _GlowFab extends StatelessWidget {
  const _GlowFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        tooltip: 'Get Suggestion',
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    );
  }
}

// ─── GOAL NOTE ──────────────────────────────────────────────────────────────

// ─── ROUTINE BANNER ─────────────────────────────────────────────────────────

/// "Your usual weekday breakfast — Rice + dal + egg. Log it?" — a proactive
/// suggestion, never an automatic log. Either button settles today for this
/// slot; "something else" hands off to voice logging.
class _RoutineBanner extends StatelessWidget {
  const _RoutineBanner({required this.slot, required this.template});
  final MealType slot;
  final MealTemplate template;

  String get _dayLabel => switch (template.dayType) {
        DayType.weekday => 'weekday',
        DayType.weekend => 'weekend',
        DayType.everyday => 'usual',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(
                icon: Icons.repeat_rounded,
                color: AppColors.accent,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your $_dayLabel ${slot.name} — ${template.foodDescription}. '
                  'Log it?',
                  style: t.bodyLarge?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              FilledButton(
                onPressed: () =>
                    context.read<HealthProvider>().logTemplateMeal(template),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
                child: const Text('Yes, log it'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  context.read<HealthProvider>().dismissRoutineSuggestion(slot);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const LogEntryScreen(initialTab: 0, autoStartVoice: true),
                  ));
                },
                child: const Text('No, something else'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalNote extends StatelessWidget {
  const _GoalNote({required this.goals});
  final HealthGoals goals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F7F4),
            Color(0xFFF7F4EE),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.flag_rounded,
            color: AppColors.teal,
            size: 32,
            iconSize: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Aiming for ${goals.calories}+ kcal \u00b7 ${goals.proteinGrams}g+ '
              'protein \u00b7 ${_k(goals.stepsMin)}\u2013${_k(goals.stepsMax)} '
              'steps \u00b7 ${_h(goals.sleepMinHours)}\u2013'
              '${_h(goals.sleepMaxHours)}h sleep',
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static String _k(int n) =>
      n % 1000 == 0 ? '${n ~/ 1000}k' : (n / 1000).toStringAsFixed(1);

  static String _h(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
