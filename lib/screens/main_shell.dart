import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/health_provider.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'log_entry_screen.dart';
import 'pantry_screen.dart';
import 'progress_screen.dart';
import 'suggestion_screen.dart';

/// Root scaffold: Home / Log / History behind a premium bottom nav.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.deepLink.addListener(_handleDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final health = context.read<HealthProvider>();
      await health.loadToday();
      await health.loadFavorites();
      // Pull the cloud copy down + flush pending local writes (no-op offline
      // or in local-only mode), then refresh.
      await health.syncNow();
      // Silently pull today's steps from Health Connect / HealthKit if the
      // permission is already granted. Never prompts here.
      await health.initHealthSync();
      await health.loadToday();
      // Requesting is a no-op once the user has already granted or denied —
      // safe to call on every launch rather than tracking a "did we ask" flag.
      await NotificationService.instance.requestPermission();
      await health.refreshReminders();
      _armMidnightTimer();
      // A cold-start tap resolves before this widget exists; pick it up now.
      _handleDeepLink();
    });
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
    }
  }

  void _onNav(int i) {
    setState(() => _index = i);
    if (i == 0) context.read<HealthProvider>().loadToday();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppAnimations.shortDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _pages[_index],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onNav,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Progress',
            ),
            NavigationDestination(
              icon: Icon(Icons.kitchen_outlined),
              selectedIcon: Icon(Icons.kitchen_rounded),
              label: 'Pantry',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }

  late final _pages = <Widget>[
    const HomeScreen(),
    const LogEntryScreen(),
    const ProgressScreen(),
    const PantryScreen(),
    const HistoryScreen(),
  ];
}
