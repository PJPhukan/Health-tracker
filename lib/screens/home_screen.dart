import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../models/user_profile.dart';
import '../providers/health_provider.dart';
import '../providers/profile_controller.dart';
import '../services/guest_service.dart';
import '../services/streak_calculator.dart';
import '../services/streak_milestone_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/guest_gate_dialog.dart';
import '../widgets/skeletons.dart';
import '../widgets/streak_milestone_sheet.dart';
import '../widgets/summary_widgets.dart';
import 'auth/signup_screen.dart';
import 'log_entry_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'suggestion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.suggestionFabKey});
  final GlobalKey? suggestionFabKey;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStreakMilestone());
  }

  Future<void> _checkStreakMilestone() async {
    if (!mounted) return;
    try {
      final progressData = await context.read<HealthProvider>().progressData();
      final streak = StreakCalculator.loggingStreak(progressData.mealLoggedDates);
      final milestone =
          await StreakMilestoneService.instance.checkUncelebratedMilestone(streak);
      if (milestone != null && mounted) {
        await showStreakMilestoneSheet(context, milestone);
      }
    } catch (_) {
      // Ignored if data not yet available
    }
  }

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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: _GlowFab(
          key: widget.suggestionFabKey,
          hasTodaySuggestion: provider.hasTodaySuggestion,
          onPressed: () {
            final guest = context.read<GuestService>();
            if (!guest.canRequestSuggestion) {
              showGuestSoftGate(context);
              return;
            }
            if (guest.isGuest) {
              guest.recordSuggestionUsed();
            }
            if (provider.hasTodaySuggestion) {
              // Ad-gated on the free tier — see suggestion_screen.dart. Fired
              // without waiting so navigation feels instant either way.
              regenerateSuggestionFlow(context);
            } else {
              context.read<HealthProvider>().getSuggestion();
            }
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SuggestionScreen()));
          },
        ),
      ),
      body: Column(
        children: [
          const _GuestModeBanner(),
          // Fixed gradient header — stays put while the content scrolls.
          _HomeHeader(greeting: _greeting()),
          const _PremiumUpsellBanner(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.teal,
              onRefresh: provider.loadToday,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 140),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (summary == null) ...[
                          // Shape-matched skeletons instead of a spinner —
                          // covers both the loading state and the one frame
                          // before MainShell's post-frame load kicks in (the
                          // splash pre-load usually means this never shows).
                          const HomeSummarySkeleton(),
                          const SizedBox(height: AppSpacing.md),
                          const HomeSuggestionSkeleton(),
                        ] else ...[
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
                            child: _SuggestionPreviewCard(
                                suggestion: provider.todaySuggestion),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          StaggeredEntrance(
                            animation: _entrance,
                            index: 3,
                            child: _GoalNote(goals: goals),
                          ),
                          if (summary.meals.isNotEmpty ||
                              summary.workouts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            StaggeredEntrance(
                              animation: _entrance,
                              index: 4,
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

// ─── PREMIUM UPSELL BANNER ──────────────────────────────────────────────────

/// A slim, dismissible "go ad-free" nudge just below the greeting. Never
/// shown to premium users. Dismissing hides it for 7 days; dismissing a
/// second time (i.e. after it reappears) hides it for good — tracked in
/// SharedPreferences, not tied to any one session.
class _PremiumUpsellBanner extends StatefulWidget {
  const _PremiumUpsellBanner();

  @override
  State<_PremiumUpsellBanner> createState() => _PremiumUpsellBannerState();
}

class _PremiumUpsellBannerState extends State<_PremiumUpsellBanner> {
  static const _kDismissedAt = 'premium_banner_dismissed_at';
  static const _kDismissCount = 'premium_banner_dismiss_count';
  static const _reshowAfter = Duration(days: 7);

  /// null while the SharedPreferences check is still in flight — the banner
  /// stays hidden rather than flashing on then off.
  bool? _eligible;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissCount = prefs.getInt(_kDismissCount) ?? 0;
    if (dismissCount >= 2) {
      if (mounted) setState(() => _eligible = false);
      return;
    }
    final dismissedAtMs = prefs.getInt(_kDismissedAt);
    final eligible = dismissedAtMs == null ||
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(dismissedAtMs)) >=
            _reshowAfter;
    if (mounted) setState(() => _eligible = eligible);
  }

  Future<void> _dismiss() async {
    setState(() => _eligible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kDismissCount, (prefs.getInt(_kDismissCount) ?? 0) + 1);
    await prefs.setInt(_kDismissedAt, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionService>().isPremium;
    if (isPremium || _eligible != true) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F7F4), Color(0xFFF7F4EE)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: kSoftShadow,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _dismiss,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '✨ Stock Plate Premium — go ad-free',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen())),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Upgrade',
                  style: t.labelLarge?.copyWith(
                      color: AppColors.teal, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GLOW FAB ───────────────────────────────────────────────────────────────

class _GlowFab extends StatelessWidget {
  const _GlowFab({super.key, required this.onPressed, required this.hasTodaySuggestion});
  final VoidCallback onPressed;

  /// Once today's suggestion exists, the FAB relabels to make clear a tap
  /// regenerates rather than fetches for the first time.
  final bool hasTodaySuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(hasTodaySuggestion
            ? 'Get New Suggestion \u{1F504}'
            : 'Get Suggestion'),
      ),
    );
  }
}

// ─── SUGGESTION PREVIEW CARD ────────────────────────────────────────────────

/// "Today's suggestion: …" below the summary metrics — a peek, not the full
/// text; tapping opens the Suggestion screen where the cached copy is
/// already loaded (see HealthProvider.initTodaySuggestion).
class _SuggestionPreviewCard extends StatelessWidget {
  const _SuggestionPreviewCard({required this.suggestion});
  final SuggestionEntry? suggestion;

  static const _previewLength = 60;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final response = suggestion?.response.trim();
    final preview = (response == null || response.isEmpty)
        ? null
        : (response.length > _previewLength
            ? '${response.substring(0, _previewLength)}…'
            : response);

    return SoftCard(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SuggestionScreen())),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.accent,
            size: 32,
            iconSize: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MetaLabel("Today's suggestion"),
                const SizedBox(height: 2),
                Text(
                  preview ?? "Tap below to get today's meal suggestion",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium,
                ),
                if (preview != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Read more →',
                    style: t.labelLarge?.copyWith(
                        color: AppColors.teal, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                        const LogEntryScreen(initialTab: 0, autoStartVoice: true, popOnSave: true),
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

/// Slim persistent banner displayed at top of Home screen in guest mode.
class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner();

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<GuestService>().isGuest;
    if (!isGuest) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.teal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                "You're in guest mode — save your data",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SignupScreen(isMotivated: true),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Sign up free →',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

