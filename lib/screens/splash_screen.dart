import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_controller.dart';
import '../providers/health_provider.dart';
import '../providers/profile_controller.dart';
import '../theme/app_theme.dart';
import 'auth/auth_gate.dart';

/// Premium animated splash shown once Flutter is up, before [AuthGate].
///
/// A single [AnimationController] drives every element through
/// [Interval]-based curves. The logo first appears dead-centre — matching the
/// native launch screen so the hand-off is seamless — then glides up into its
/// wordmark position as the app name and tagline fade in beneath it. When the
/// timeline finishes the screen fades and eases down into the auth gate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2300);

  /// How far the logo sits below its final resting spot at t=0 — roughly half
  /// the height of the (initially invisible) name + tagline block, so the mark
  /// reads as vertically centred before it travels up.
  static const _logoTravel = 56.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );

  // Staggered slices of the timeline. Each element overlaps the previous one
  // slightly so the sequence reads as one continuous motion.
  late final Animation<double> _glow = _curved(0.00, 0.60, Curves.easeOutSine);
  // Quick fade only to smooth any seam with the native launch frame.
  late final Animation<double> _logoFade = _curved(0.00, 0.12);
  late final Animation<double> _logoScale = Tween(begin: 1.08, end: 1.0)
      .animate(_curved(0.00, 0.34, Curves.easeOutCubic));
  // The "move to the second section" gesture: centre -> wordmark slot.
  late final Animation<double> _logoRise = Tween(begin: _logoTravel, end: 0.0)
      .animate(_curved(0.16, 0.52, Curves.easeOutCubic));
  late final Animation<double> _nameFade = _curved(0.34, 0.60);
  late final Animation<double> _nameSlide = Tween(begin: 16.0, end: 0.0)
      .animate(_curved(0.34, 0.64, Curves.easeOutCubic));
  late final Animation<double> _taglineFade = _curved(0.52, 0.80);

  Animation<double> _curved(double begin, double end,
          [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  /// Absolute ceiling on how long the splash can hold the user, no matter how
  /// slow the network/device is — after this, we navigate regardless and let
  /// the destination screen show its own (already-existing) loading state.
  static const _hardCap = Duration(seconds: 5);

  bool _animationDone = false;
  bool _preloadDone = false;
  bool _navigated = false;
  Timer? _hardCapTimer;

  @override
  void initState() {
    super.initState();
    // The animation and the data pre-load race each other; whichever is
    // slower decides when we actually navigate — see _maybeNavigate.
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationDone = true;
        _maybeNavigate();
      }
    });
    _c.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _preload().then((_) {
        _preloadDone = true;
        _maybeNavigate();
      });
    });
    _hardCapTimer = Timer(_hardCap, _maybeNavigate);
  }

  @override
  void dispose() {
    _hardCapTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// Warms every provider the very first frame after the splash needs, in
  /// parallel with the animation, so `AuthGate` and `MainShell` resolve
  /// instantly instead of showing their own brief spinners right after we
  /// hand off. Best-effort only — any failure here just means the
  /// destination screen falls back to its own existing loading state, per
  /// the "polish only, no functional change" constraint.
  Future<void> _preload() async {
    try {
      final auth = context.read<AuthController>();
      final profile = context.read<ProfileController>();
      final health = context.read<HealthProvider>();

      await Future.wait([
        _waitForAuthResolved(auth)
            .timeout(const Duration(seconds: 3), onTimeout: () {}),
        health
            .loadToday()
            .timeout(const Duration(seconds: 3), onTimeout: () {}),
        // Warms the shared_preferences platform channel so the
        // pantry-onboarding gate's first check (further down the flow)
        // resolves instantly instead of paying the first-call cost after
        // navigation.
        SharedPreferences.getInstance().timeout(const Duration(seconds: 3)),
      ]);

      if (auth.stage == AuthStage.localOnly ||
          auth.stage == AuthStage.signedIn) {
        await profile
            .bind(auth.profileId)
            .timeout(const Duration(seconds: 3), onTimeout: () {});
        // Needs the goals `profile.bind` just loaded, and today's data
        // loaded above. Fire-and-forget rather than awaited: it may hit the
        // network (the Gemini call), and navigation must never wait on
        // that — Home's existing preview card already handles "not ready
        // yet" with a placeholder, exactly as it did before this screen
        // called it early. HealthProvider swallows its own errors.
        unawaited(health.initTodaySuggestion());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Splash pre-load failed: $e');
    }
  }

  /// Resolves once [AuthController] leaves `checking` (already resolved
  /// instantly in local-only mode; waits for the first cached-session
  /// callback otherwise).
  Future<void> _waitForAuthResolved(AuthController auth) {
    if (auth.stage != AuthStage.checking) return Future.value();
    final completer = Completer<void>();
    void listener() {
      if (auth.stage != AuthStage.checking) {
        auth.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    auth.addListener(listener);
    return completer.future;
  }

  void _maybeNavigate() {
    if (_navigated || !mounted) return;
    final hardCapped = !(_hardCapTimer?.isActive ?? true);
    if (hardCapped || (_animationDone && _preloadDone)) {
      _navigated = true;
      _goHome();
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) {
          final eased =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(eased),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft teal glow that breathes in behind the mark and rides
              // up with it.
              Transform.translate(
                offset: Offset(0, _logoRise.value),
                child: Opacity(
                  opacity: _glow.value * 0.5,
                  child: Container(
                    width: 460,
                    height: 460,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.tealLight.withValues(alpha: 0.28),
                          AppColors.cream.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: Offset(0, _logoRise.value),
                    child: Opacity(
                      opacity: _logoFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Image.asset(
                          'assets/branding/logo.png',
                          width: 132,
                          height: 132,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Opacity(
                    opacity: _nameFade.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, _nameSlide.value),
                      child: Text(
                        'Stock Plate',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: AppColors.teal),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Opacity(
                    opacity: _taglineFade.value.clamp(0.0, 1.0),
                    child: Text(
                      'Small steps, better days',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
