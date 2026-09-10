import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _goHome();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
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
