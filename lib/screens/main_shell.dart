import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/health_provider.dart';
import '../services/guest_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/tts_service.dart';
import '../services/tutorial_service.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'log_entry_screen.dart';
import 'onboarding/onboarding_flow.dart';
import 'pantry_screen.dart';
import 'progress_screen.dart';
import 'suggestion_screen.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/guest_gate_dialog.dart';
import '../widgets/offline_banner.dart';

/// Root scaffold: Home / Log / History behind a premium bottom nav.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _midnightTimer;

  final GlobalKey _suggestionFabKey = GlobalKey();
  final GlobalKey _pantryNavKey = GlobalKey();
  final GlobalKey _logNavKey = GlobalKey();
  final GlobalKey _progressNavKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.deepLink.addListener(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final health = context.read<HealthProvider>();
      await health.loadToday();
      await health.loadFavorites();
      await health.loadTemplates();
      // Pull the cloud copy down + flush pending local writes (no-op offline
      // or in local-only mode), then refresh.
      await health.syncNow();
      // Silently pull today's steps from Health Connect / HealthKit if the
      // permission is already granted. Never prompts here.
      await health.initHealthSync();
      await health.loadToday();
      // Shows today's cached suggestion instantly, or generates one silently
      // if this is the first open of a new day. Never shows a spinner for
      // this — Home's preview card just displays a placeholder until it
      // resolves.
      await health.initTodaySuggestion();
      // Requesting is a no-op once the user has already granted or denied —
      // safe to call on every launch rather than tracking a "did we ask" flag.
      await NotificationService.instance.requestPermission();
      await health.refreshReminders();
      _armMidnightTimer();
      // A cold-start tap resolves before this widget exists; pick it up now.
      _handleDeepLink();

      if (GuestService.instance.pendingProfilePrompt && mounted) {
        await GuestService.instance.setPendingProfilePrompt(false);
        _showCompleteProfileBottomSheet();
      } else {
        _checkTutorial();
      }
    });
  }

  void _checkTutorial() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        TutorialService.instance.showTutorialIfNeeded(
          context: context,
          suggestionKey: _suggestionFabKey,
          pantryKey: _pantryNavKey,
          logKey: _logNavKey,
          progressKey: _progressNavKey,
        );
      }
    });
  }

  Future<void> _showCompleteProfileBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.tealLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_pin_rounded,
                  color: AppColors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Complete your profile to get personalized suggestions',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tell us a bit about yourself so we can calculate your exact energy needs.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
                    );
                  },
                  child: const Text('Set up now'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            ],
          ),
        ),
      ),
    );
    _checkTutorial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.deepLink.removeListener(_handleDeepLink);
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// Re-runs [HealthProvider.refreshReminders] once at the next local
  /// midnight (while the app happens to be open), then rearms for the day
  /// after — covers the "reschedule at midnight" half of the requirement
  /// without a background task scheduler.
  void _armMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () async {
      if (!mounted) return;
      await context.read<HealthProvider>().refreshReminders();
      _armMidnightTimer();
    });
  }

  void _handleDeepLink() {
    final link = NotificationService.instance.deepLink.value;
    if (link == null || !mounted) return;
    NotificationService.instance.deepLink.value = null; // consume once
    switch (link) {
      case NotificationDeepLink.mealLog:
        setState(() => _index = 1);
      case NotificationDeepLink.progress:
        setState(() => _index = 2);
      case NotificationDeepLink.suggestion:
        context.read<HealthProvider>().getSuggestion();
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SuggestionScreen()));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final health = context.read<HealthProvider>();
      health.syncNow();
      health.refreshStepsFromHealth().then((_) => health.loadToday());
      health.refreshReminders();
      context.read<SubscriptionService>().refresh();
      _armMidnightTimer();
    } else {
      // Minimizing mid-playback shouldn't keep talking in the background —
      // this is a reading aid, not a music player.
      TtsService.instance.stop();
    }
  }

  void _onNav(int i) {
    setState(() => _index = i);
    if (i == 0) context.read<HealthProvider>().loadToday();
  }

  void _handleSuggestionTap() {
    final guest = context.read<GuestService>();
    if (!guest.canRequestSuggestion) {
      showGuestSoftGate(context);
      return;
    }
    if (guest.isGuest) {
      guest.recordSuggestionUsed();
    }
    final health = context.read<HealthProvider>();
    if (health.hasTodaySuggestion) {
      regenerateSuggestionFlow(context);
    } else {
      health.getSuggestion();
    }
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SuggestionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final lowPantryCount = context.select<HealthProvider, int>(
      (h) => h.pantry.where((i) => i.isLow).length,
    );
    final hasLowPantry = lowPantryCount >= 3;

    return Scaffold(
      extendBody: true,
      floatingActionButton: _index == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlowFab(
                key: _suggestionFabKey,
                hasTodaySuggestion:
                    context.watch<HealthProvider>().hasTodaySuggestion,
                onPressed: _handleSuggestionTap,
              ),
            )
          : null,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppAnimations.shortDuration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: _pages[_index],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _index,
        onTap: _onNav,
        items: [
          const FloatingNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          FloatingNavItem(
            key: _logNavKey,
            icon: Icons.add_circle_outline_rounded,
            selectedIcon: Icons.add_circle_rounded,
            label: 'Log',
          ),
          FloatingNavItem(
            key: _progressNavKey,
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights_rounded,
            label: 'Progress',
          ),
          FloatingNavItem(
            key: _pantryNavKey,
            icon: Icons.kitchen_outlined,
            selectedIcon: Icons.kitchen_rounded,
            label: 'Pantry',
            showBadge: hasLowPantry,
            badgeColor: AppColors.behind,
          ),
          const FloatingNavItem(
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today_rounded,
            label: 'History',
          ),
        ],
      ),
    );
  }

  late final _pages = <Widget>[
    HomeScreen(suggestionFabKey: _suggestionFabKey),
    const LogEntryScreen(),
    const ProgressScreen(),
    const PantryScreen(),
    const HistoryScreen(),
  ];
}
