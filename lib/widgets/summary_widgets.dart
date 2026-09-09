import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/health_goal.dart';
import '../theme/app_theme.dart';
import 'common.dart';

GoalStatus _sleepStatus(DailySummary s) {
  if (s.sleep == null) return GoalStatus.neutral;
  return s.sleepHours >= HealthGoal.sleepMinHours - 0.25
      ? GoalStatus.onTrack
      : GoalStatus.behind;
}

GoalStatus _stepsStatus(DailySummary s) {
  if (s.steps == null) return GoalStatus.neutral;
  return s.stepCount >= HealthGoal.stepsMin
      ? GoalStatus.onTrack
      : GoalStatus.behind;
}

GoalStatus _mealsStatus(DailySummary s) {
  if (s.meals.isEmpty) return GoalStatus.neutral;
  return s.meals.length >= 3 ? GoalStatus.onTrack : GoalStatus.behind;
}

/// One stat tile inside the summary grid — with icon badge and subtle styling.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
  });

  final IconData icon;
  final String label;
  final String value;
  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconBadge(
            icon: icon,
            color: status.fg,
            size: 26,
            iconSize: 14,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: t.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  maxLines: 1,
                  style: t.labelSmall?.copyWith(
                      color: AppColors.textSecondary, letterSpacing: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today-at-a-glance card used on Home — with entrance animation.
class DailySummaryCard extends StatefulWidget {
  const DailySummaryCard({super.key, required this.summary});

  final DailySummary summary;

  @override
  State<DailySummaryCard> createState() => _DailySummaryCardState();
}

/// The most recently added meals and workouts for the current day.
class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key, required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = <_RecentActivity>[
      for (final meal in summary.meals)
        _RecentActivity(
          timestamp: meal.timestamp,
          icon: Icons.restaurant_menu_rounded,
          color: AppColors.accent,
          title: _capitalize(meal.mealType.name),
          subtitle: meal.foodDescription,
        ),
      for (final workout in summary.workouts)
        _RecentActivity(
          timestamp: workout.timestamp,
          icon: Icons.fitness_center_rounded,
          color: AppColors.onTrack,
          title: workout.exerciseType,
          subtitle: '${workout.durationMinutes} min'
              '${workout.notes.isEmpty ? '' : ' · ${workout.notes}'}',
        ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final latest = entries.take(3).toList();
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaLabel('Latest activity'),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < latest.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: latest[i].icon,
                  color: latest[i].color,
                  size: 34,
                  iconSize: 17,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(latest[i].title, style: t.titleMedium),
                      Text(
                        latest[i].subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != latest.length - 1) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _RecentActivity {
  const _RecentActivity({
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final String timestamp;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _DailySummaryCardState extends State<DailySummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppAnimations.entranceDuration,
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final tiles = [
      _StatTile(
        icon: Icons.restaurant_menu_rounded,
        label: 'meals logged',
        value: '${s.meals.length}',
        status: _mealsStatus(s),
      ),
      _StatTile(
        icon: s.workoutDone
            ? Icons.check_circle_rounded
            : Icons.fitness_center_rounded,
        label: 'workout',
        value: s.workoutDone ? 'Done' : 'Not yet',
        status: s.workoutDone ? GoalStatus.onTrack : GoalStatus.neutral,
      ),
      _StatTile(
        icon: Icons.bedtime_rounded,
        label: 'sleep',
        value:
            s.sleep == null ? '\u2014' : '${s.sleepHours.toStringAsFixed(1)}h',
        status: _sleepStatus(s),
      ),
      _StatTile(
        icon: Icons.directions_walk_rounded,
        label: 'steps',
        value: s.steps == null ? '\u2014' : _compact(s.stepCount),
        status: _stepsStatus(s),
      ),
    ];

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: MetaLabel('Today at a glance')),
              if (s.weight != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monitor_weight_rounded,
                            size: 14, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text(
                          '${s.weight!.weightKg.toStringAsFixed(1)} kg',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) {
              const gap = AppSpacing.sm;
              final w = (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    StaggeredEntrance(
                      animation: _entrance,
                      index: i,
                      staggerDelay: 0.1,
                      child: SizedBox(width: w, height: 112, child: tiles[i]),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$n';
  }
}
