import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/profile_controller.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import 'pantry_onboarding_screen.dart';

/// Sits between "goals onboarding done" and the app shell: shows the pantry
/// checklist exactly once per account (first run only), then never again —
/// see "Rebuild pantry checklist" in Settings for a deliberate redo.
class PantryOnboardingGate extends StatefulWidget {
  const PantryOnboardingGate({super.key});

  @override
  State<PantryOnboardingGate> createState() => _PantryOnboardingGateState();
}

class _PantryOnboardingGateState extends State<PantryOnboardingGate> {
  static String _flagKey(String profileId) => 'v4_pantry_onboarded_$profileId';

  bool? _needsSetup;
  String? _checkedFor;

  Future<void> _check(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _checkedFor = profileId;
      _needsSetup = prefs.getBool(_flagKey(profileId)) != true;
    });
  }

  Future<void> _markDone(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flagKey(profileId), true);
    if (mounted) setState(() => _needsSetup = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileId = context.watch<ProfileController>().profileId;
    if (_checkedFor != profileId) {
      // Kicks off async work as a side effect of build, guarded so it only
      // fires once per profile id change — the loading state below covers it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _check(profileId));
      return const _Waiting();
    }
    if (_needsSetup == null) return const _Waiting();
    if (_needsSetup == true) {
      return PantryOnboardingScreen(
        isFirstRun: true,
        onFirstRunDone: () => _markDone(profileId),
      );
    }
    return const MainShell();
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
    );
  }
}
