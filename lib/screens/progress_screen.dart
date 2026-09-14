import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../models/models.dart';
import '../providers/health_provider.dart';
import '../services/streak_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/skeletons.dart';

/// A calm dashboard: two streak cards, then one chart per metric. Charts are
/// deliberately non-interactive for v3.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<ProgressData> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<HealthProvider>().progressData();
  }

  Future<void> _refresh() async {
    setState(() => _future = context.read<HealthProvider>().progressData());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Progress',
            subtitle: 'Streaks and trends',
            trailing:
                AnimatedSparkleIcon(icon: Icons.insights_rounded, size: 24),
          ),
          Expanded(
            child: FutureBuilder<ProgressData>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SingleChildScrollView(
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                    child: ProgressChartsSkeleton(),
                  );
                }
                final data = snap.data!;
                return RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, 96),
                    children: [
                      _StreakRow(data: data),
                      if (!data.hasEnoughDataForCharts)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xl),
                          child: EmptyState(
                            icon: Icons.show_chart_rounded,
                            title: 'No trends yet',
                            message: AppStrings.progressEmptyMessage,
                          ),
                        )
                      else ...[
                        const SizedBox(height: AppSpacing.lg),
                        _WeightChartCard(entries: data.weight),
                        const SizedBox(height: AppSpacing.md),
                        _StepsChartCard(
                            entries: data.steps, target: data.goals.stepsMin),
                        const SizedBox(height: AppSpacing.md),
                        _SleepChartCard(entries: data.sleep),
                        const SizedBox(height: AppSpacing.md),
                        _MealsChartCard(countsByDay: data.mealCountsByDay),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── streaks ────────────────────────────────────────────────────────────────

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.data});
  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final logging =
        StreakCalculator.loggingStreak(data.mealLoggedDates);
    final goal = StreakCalculator.stepGoalStreak(
        data.steps, data.goals.stepsMin);
    return Row(
      children: [
        Expanded(
          child: _StreakCard(
            emoji: '🔥',
            value: logging,
            label: logging == 1 ? 'day logging streak' : 'day logging streak',
            highlighted: logging > 0,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StreakCard(
            emoji: '🎯',
            value: goal,
            label: 'day step-goal streak',
            highlighted: goal > 0,
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.highlighted,
  });

  final String emoji;
  final int value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.teal : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$value',
            style: t.displaySmall?.copyWith(
              color: highlighted ? Colors.white : AppColors.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: t.bodyMedium?.copyWith(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── chart scaffolding ──────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleMedium),
          if (subtitle != null)
            Text(subtitle!,
                style: t.labelSmall),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 150, child: child),
        ],
      ),
    );
  }
}

const _axisStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 11,
  fontWeight: FontWeight.w500,
);

FlGridData _horizontalGrid(double interval) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) => const FlLine(
        color: AppColors.divider,
        strokeWidth: 1,
      ),
    );

/// 7-day window ending today, as `[dateKey, weekday-letter]` pairs.
List<({String key, String label})> _last7Days() {
  final today = DateTime.now();
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = today.subtract(Duration(days: i));
        return (key: dateKey(d), label: DateFormat('E').format(d)[0]);
      }(),
  ];
}

// ─── weight ─────────────────────────────────────────────────────────────────

class _WeightChartCard extends StatelessWidget {
  const _WeightChartCard({required this.entries});
  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return _ChartCard(
        title: 'Weight',
        subtitle: 'last 30 days',
        child: Center(
          child: Text(
            entries.isEmpty
                ? 'Log your weight to see the trend'
                : 'One more entry and the line appears',
            style: _axisStyle,
          ),
        ),
      );
    }

    final first = DateTime.parse(entries.first.date);
    final spots = [
      for (final e in entries)
        FlSpot(
          DateTime.parse(e.date).difference(first).inDays.toDouble(),
          e.weightKg,
        ),
    ];
    final weights = entries.map((e) => e.weightKg).toList();
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxY = (weights.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();
    final maxX = spots.last.x;

    return _ChartCard(
      title: 'Weight',
      subtitle: 'last 30 days · kg',
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: maxX == 0 ? 1 : maxX,
          gridData: _horizontalGrid(((maxY - minY) / 3).clamp(1, 100)),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: ((maxY - minY) / 3).clamp(1, 100),
                getTitlesWidget: (v, _) =>
                    Text(v.toStringAsFixed(0), style: _axisStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (maxX / 3).clamp(1, 1000),
                getTitlesWidget: (v, _) {
                  final d = first.add(Duration(days: v.round()));
                  return Text(DateFormat('d/M').format(d), style: _axisStyle);
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: AppColors.teal,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.teal.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── shared bar chart ───────────────────────────────────────────────────────

class _DayBarChart extends StatelessWidget {
  const _DayBarChart({
    required this.values,
    required this.labels,
    required this.maxY,
    required this.yLabelStep,
    this.targetLine,
    this.yFormatter,
  });

  final List<double> values;
  final List<String> labels;
  final double maxY;
  final double yLabelStep;
  final double? targetLine;
  final String Function(double)? yFormatter;

  @override
  Widget build(BuildContext context) {
    final fmt = yFormatter ?? (v) => v.toStringAsFixed(0);
    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: const BarTouchData(enabled: false),
        gridData: _horizontalGrid(yLabelStep),
        borderData: FlBorderData(show: false),
        extraLinesData: targetLine == null
            ? const ExtraLinesData()
            : ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: targetLine!,
                  color: AppColors.accent.withValues(alpha: 0.7),
                  strokeWidth: 1.5,
                  dashArray: [4, 4],
                ),
              ]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: yLabelStep,
              getTitlesWidget: (v, _) => Text(fmt(v), style: _axisStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Text(labels[i], style: _axisStyle);
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                color: AppColors.teal,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ]),
        ],
      ),
    );
  }
}

// ─── steps ──────────────────────────────────────────────────────────────────

class _StepsChartCard extends StatelessWidget {
  const _StepsChartCard({required this.entries, required this.target});
  final List<StepsEntry> entries;
  final int target;

  @override
  Widget build(BuildContext context) {
    final days = _last7Days();
    final byDate = {for (final e in entries) e.date: e.stepCount};
    final values = [
      for (final d in days) (byDate[d.key] ?? 0).toDouble(),
    ];
    final peak = [
      ...values,
      target.toDouble(),
    ].reduce((a, b) => a > b ? a : b);
    final maxY = (peak * 1.15 / 2000).ceil() * 2000.0;

    return _ChartCard(
      title: 'Daily steps',
      subtitle: 'last 7 days · dashed line = your goal',
      child: _DayBarChart(
        values: values,
        labels: [for (final d in days) d.label],
        maxY: maxY == 0 ? 2000 : maxY,
        yLabelStep: (maxY / 3).clamp(1000, 100000),
        targetLine: target.toDouble(),
        yFormatter: (v) =>
            v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
      ),
    );
  }
}

// ─── sleep ──────────────────────────────────────────────────────────────────

class _SleepChartCard extends StatelessWidget {
  const _SleepChartCard({required this.entries});
  final List<SleepEntry> entries;

  @override
  Widget build(BuildContext context) {
    final days = _last7Days();
    final byDate = {for (final e in entries) e.date: e.totalHours};
    final values = [for (final d in days) (byDate[d.key] ?? 0).toDouble()];

    return _ChartCard(
      title: 'Sleep',
      subtitle: 'last 7 days · hours',
      child: _DayBarChart(
        values: values,
        labels: [for (final d in days) d.label],
        maxY: 12,
        yLabelStep: 4,
      ),
    );
  }
}

// ─── meals (calorie proxy) ──────────────────────────────────────────────────

class _MealsChartCard extends StatelessWidget {
  const _MealsChartCard({required this.countsByDay});
  final Map<String, int> countsByDay;

  @override
  Widget build(BuildContext context) {
    final days = _last7Days();
    final values = [
      for (final d in days) (countsByDay[d.key] ?? 0).toDouble(),
    ];

    return _ChartCard(
      title: 'Meals per day',
      subtitle: 'last 7 days · calorie-intake proxy',
      child: _DayBarChart(
        values: values,
        labels: [for (final d in days) d.label],
        maxY: 6,
        yLabelStep: 2,
      ),
    );
  }
}
