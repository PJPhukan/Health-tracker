import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import 'login_screen.dart';

/// Decides what the user sees once the splash finishes.
///
/// * `checking`   → brief spinner while the cached session resolves
/// * `localOnly`  → no Firebase config: straight into the app, on-device only
/// * `signedOut`  → Login
/// * `signedIn`   → the app shell
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return switch (auth.stage) {
      AuthStage.checking => const _Waiting(),
      AuthStage.signedOut => const LoginScreen(),
      AuthStage.localOnly || AuthStage.signedIn => const MainShell(),
    };
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
