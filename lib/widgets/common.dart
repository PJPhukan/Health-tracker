import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A soft, borderless card with generous padding and low-contrast elevation.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small uppercase meta label ("TODAY", "SUMMARY").
class MetaLabel extends StatelessWidget {
  const MetaLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );
}

/// A calm empty-state block: soft icon, friendly copy, lots of air.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.teal),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: t.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onButtonPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft pulsing icon used for calm loading states.
class PulsingIcon extends StatefulWidget {
  const PulsingIcon(
      {super.key, this.icon = Icons.auto_awesome, this.size = 44});
  final IconData icon;
  final double size;

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        final v = curve.value;
        return Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(AppColors.accentSoft, AppColors.surfaceMuted, v),
          ),
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 0.92 + 0.12 * v,
            child:
                Icon(widget.icon, size: widget.size, color: AppColors.accent),
          ),
        );
      },
    );
  }
}

// ─── GRADIENT HEADER ────────────────────────────────────────────────────────

/// Reusable gradient header used across all screens.
/// Provides a deep-teal gradient with rounded bottom corners,
/// optional back button, and title/subtitle.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.bottomPadding = AppSpacing.xl,
  });

  final String title;
  final String? subtitle;

  /// Optional widget shown after the title (e.g. an animated icon).
  final Widget? trailing;

  /// Optional widget shown before the title (e.g. a back button).
  /// If null, a back button is shown when the navigator can pop.
  final Widget? leading;

  /// Padding below the title row.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();

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
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canPop || leading != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: leading ?? _DefaultBackButton(),
                ),
              Row(
                children: [
                  if (trailing != null) ...[
                    trailing!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: t.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: t.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── STAGGERED ENTRANCE ─────────────────────────────────────────────────────

/// Wraps a child in a staggered slide-up + fade-in animation.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
    this.staggerDelay = 0.12,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;
  final double staggerDelay;

  @override
  Widget build(BuildContext context) {
    final delay = (index * staggerDelay).clamp(0.0, 0.7);
    final interval = Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
        curve: AppAnimations.entranceCurve);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = interval.transform(animation.value);
        return Transform.translate(
          offset: Offset(0, 24 * (1 - v)),
          child: Opacity(opacity: v, child: child),
        );
      },
    );
  }
}

// ─── ANIMATED SPARKLE ICON ──────────────────────────────────────────────────

/// Gently breathing icon for header decoration — a slow scale pulse, no spin.
class AnimatedSparkleIcon extends StatefulWidget {
  const AnimatedSparkleIcon({
    super.key,
    this.icon = Icons.auto_awesome_rounded,
    this.size = 26,
  });
  final IconData icon;
  final double size;

  @override
  State<AnimatedSparkleIcon> createState() => _AnimatedSparkleIconState();
}

class _AnimatedSparkleIconState extends State<AnimatedSparkleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale =
            1.0 + 0.06 * Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Transform.scale(
            scale: scale,
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: widget.size,
            ),
          ),
        );
      },
    );
  }
}

// ─── ICON BADGE ─────────────────────────────────────────────────────────────

/// A small colored circle behind an icon — used in list rows and stat tiles.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.teal,
    this.size = 36,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

// ─── SHIMMER BLOCK ──────────────────────────────────────────────────────────

/// A shimmering placeholder bar for loading skeletons.
class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    required this.controller,
    required this.width,
    this.height = 18,
  });

  final AnimationController controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final shimmerPos = controller.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * shimmerPos, 0),
              end: Alignment(-0.4 + 2 * shimmerPos, 0),
              colors: [
                AppColors.surfaceMuted,
                AppColors.surfaceMuted.withValues(alpha: 0.4),
                AppColors.surfaceMuted,
              ],
            ),
          ),
        );
      },
    );
  }
}
