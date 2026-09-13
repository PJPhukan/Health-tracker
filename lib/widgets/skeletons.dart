import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Per-widget loading placeholders, shaped like the real content they stand
/// in for, so the first frame after navigation never shows a blank area or a
/// full-screen spinner. Only used for the brief window (if any) where a
/// splash pre-load didn't finish in time — see [SplashScreen].
///
/// Wraps the whole subtree in one [Shimmer.fromColors] so every block sweeps
/// in sync, tinted to the app's warm off-white palette rather than the
/// package's default grey.
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceMuted,
      highlightColor: AppColors.cream,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// One rounded placeholder rectangle.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, this.height, this.radius = 8});
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // The shimmer package only animates the alpha of this color against
        // its base/highlight pair — the exact shade barely matters — but
        // white keeps the sweep crisp against AppColors.surfaceMuted.
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Stands in for [DailySummaryCard]'s 4-tile grid on Home.
class HomeSummarySkeleton extends StatelessWidget {
  const HomeSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          boxShadow: kSoftShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBlock(width: 140, height: 14),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, c) {
                const gap = AppSpacing.sm;
                final w = (c.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: w,
                        height: 112,
                        child: const _SkeletonBlock(
                            radius: AppSpacing.radiusSm, height: 112),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for [_SuggestionPreviewCard] on Home — a short 2-3 line card.
class HomeSuggestionSkeleton extends StatelessWidget {
  const HomeSuggestionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          boxShadow: kSoftShadow,
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBlock(width: 32, height: 32, radius: 16),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(width: 100, height: 10),
                  SizedBox(height: 8),
                  _SkeletonBlock(height: 12),
                  SizedBox(height: 6),
                  _SkeletonBlock(width: 180, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the Progress screen's chart cards while [ProgressData]
/// loads — same card chrome, chart-sized rectangle instead of the plot.
class ProgressChartsSkeleton extends StatelessWidget {
  const ProgressChartsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: _SkeletonBlock(height: 96, radius: AppSpacing.radius)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: _SkeletonBlock(height: 96, radius: AppSpacing.radius)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            const _ChartCardSkeleton(),
            if (i != 3) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ChartCardSkeleton extends StatelessWidget {
  const _ChartCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBlock(width: 110, height: 14),
          SizedBox(height: AppSpacing.md),
          // Matches _ChartCard's fixed 150-tall chart area.
          SizedBox(height: 150, child: _SkeletonBlock(height: 150)),
        ],
      ),
    );
  }
}

/// Stands in for 3 [_DayCard]s on the History screen.
class HistoryListSkeleton extends StatelessWidget {
  const HistoryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Column(
        children: [
          _DayCardSkeleton(),
          SizedBox(height: AppSpacing.sm),
          _DayCardSkeleton(),
          SizedBox(height: AppSpacing.sm),
          _DayCardSkeleton(),
        ],
      ),
    );
  }
}

class _DayCardSkeleton extends StatelessWidget {
  const _DayCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: const Row(
        children: [
          _SkeletonBlock(width: 40, height: 40, radius: 12),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBlock(width: 140, height: 14),
                SizedBox(height: 8),
                _SkeletonBlock(width: 90, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
