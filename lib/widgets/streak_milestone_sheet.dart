import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/streak_milestone_service.dart';
import '../theme/app_theme.dart';

Future<void> showStreakMilestoneSheet(BuildContext context, int days) async {
  await StreakMilestoneService.instance.markMilestoneCelebrated(days);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StreakMilestoneSheet(days: days),
  );
}

class _StreakMilestoneSheet extends StatefulWidget {
  const _StreakMilestoneSheet({required this.days});
  final int days;

  @override
  State<_StreakMilestoneSheet> createState() => _StreakMilestoneSheetState();
}

class _StreakMilestoneSheetState extends State<_StreakMilestoneSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  String get _subtitle {
    switch (widget.days) {
      case 3:
        return "You're building real momentum. Great start!";
      case 7:
        return "You're building a real habit. Keep going!";
      case 14:
        return "Two whole weeks of consistency. You're unstoppable!";
      case 30:
        return "A full month of logging. You're a true champion!";
      default:
        return "You're building a real habit. Keep going!";
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Animated Starburst & Flame
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      size: const Size(140, 140),
                      painter: _StarburstPainter(
                        progress: CurvedAnimation(
                          parent: _controller,
                          curve: Curves.easeOutCubic,
                        ).value,
                      ),
                    ),
                  ),
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
                    ),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF8A00),
                            Color(0xFFE52E71),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8A00).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '🔥',
                          style: TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              '🔥 ${widget.days}-Day Streak!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Keep it up button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Keep it up →',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _StarburstPainter extends CustomPainter {
  _StarburstPainter({required this.progress});
  final double progress;

  static const int particleCount = 12;
  static final List<Color> colors = [
    const Color(0xFFFF8A00),
    const Color(0xFFFFD600),
    const Color(0xFF00C9A7),
    const Color(0xFFE52E71),
    const Color(0xFF845EC2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * 2 * math.pi / particleCount) + (progress * 0.4);
      final currentRadius = 35 + (maxRadius - 35) * progress;
      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);

      final color = colors[i % colors.length];
      final paint = Paint()
        ..color = color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      final particleSize = (1.0 - progress * 0.6) * 4.5;
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarburstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
