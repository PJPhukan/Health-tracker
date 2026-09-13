import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../providers/profile_controller.dart';
import '../../services/guest_service.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../onboarding/pantry_onboarding_gate.dart';
import '../quick_start/quick_start_flow.dart';
import 'login_screen.dart';

/// Decides what the user sees once the splash finishes.
///
/// * First-run (new user, no account, no guest session) → QuickStartFlow
/// * Guest mode active → MainShell
/// * Returning users:
///   * `checking`   → brief spinner while the cached session resolves
///   * `signedOut`  → Login  (only reachable when Firebase is configured)
///   * `localOnly` / `signedIn` → bind the profile, then:
///       * onboarding not done → OnboardingFlow
///       * otherwise           → PantryOnboardingGate (first-run pantry
///         checklist, then the app shell)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _boundProfileId;

  /// Keep [ProfileController] pointed at whoever is signed in. Deferred to a
  /// post-frame callback so `bind()`'s notifyListeners never fires mid-build.
  void _syncProfileBinding(AuthController auth) {
    if (auth.stage == AuthStage.checking) return;
    if (auth.stage == AuthStage.signedOut) {
      // Drop the binding so signing back in (even as the same uid) re-binds.
      _boundProfileId = null;
      return;
    }
    final wanted = auth.profileId; // uid, or 'local'
    if (wanted == _boundProfileId) return;
    // The splash screen's pre-load may have already bound (and loaded) this
    // exact profile before we ever got here — skip the redundant reload so
    // we don't flash `_Waiting()` right after the splash hands off.
    final profile = context.read<ProfileController>();
    if (profile.profileId == wanted && profile.state == ProfileState.ready) {
      _boundProfileId = wanted;
      return;
    }
    _boundProfileId = wanted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileController>().bind(wanted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final guest = context.watch<GuestService>();

    // 1. First-run experience for completely new users
    if (!guest.hasSeenQuickStart && auth.user == null && !guest.isGuest) {
      return const QuickStartFlow();
    }

    // 2. Active guest mode session
    if (guest.isGuest && auth.user == null) {
      return const MainShell();
    }

    _syncProfileBinding(auth);

    switch (auth.stage) {
      case AuthStage.checking:
        return const _Waiting();
      case AuthStage.signedOut:
        return const LoginScreen();
      case AuthStage.localOnly:
      case AuthStage.signedIn:
        final profile = context.watch<ProfileController>();
        if (profile.state == ProfileState.loading) return const _Waiting();
        if (profile.needsOnboarding) return const OnboardingFlow();
        return const PantryOnboardingGate();
    }
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
