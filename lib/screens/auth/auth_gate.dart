import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../providers/profile_controller.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import '../onboarding/onboarding_flow.dart';
import 'login_screen.dart';

/// Decides what the user sees once the splash finishes.
///
/// * `checking`   → brief spinner while the cached session resolves
/// * `signedOut`  → Login  (only reachable when Firebase is configured)
/// * `localOnly` / `signedIn` → bind the profile, then:
///     * onboarding not done → OnboardingFlow
///     * otherwise           → the app shell
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
    if (auth.stage == AuthStage.checking ||
        auth.stage == AuthStage.signedOut) {
      return;
    }
    final wanted = auth.profileId; // uid, or 'local'
    if (wanted == _boundProfileId) return;
    _boundProfileId = wanted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileController>().bind(wanted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
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
        return const MainShell();
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
