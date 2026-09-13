import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/skeletons.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<String>> _dates;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppAnimations.entranceDuration,
  )..forward();

  @override
  void initState() {
    super.initState();
    _dates = context.read<HealthProvider>().recentDates(days: 30);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _refreshHistory() => setState(
        () => _dates = context.read<HealthProvider>().recentDates(days: 30),
      );

  String _friendly(String date) {
    final d = DateTime.parse(date);
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Gradient header
          const GradientHeader(
            title: 'History',
            subtitle: 'Your recent activity',
            trailing: AnimatedSparkleIcon(
              icon: Icons.calendar_today_rounded,
              size: 22,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _dates,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SingleChildScrollView(
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                    child: HistoryListSkeleton(),
                  );
                }
                final dates = snap.data!;
                if (dates.isEmpty) {
                  return const EmptyState(
                    icon: Icons.auto_stories_rounded,
                    title: 'Nothing logged yet',
                    message:
                        'Your logged days will show up here.\nStart by adding a meal or a walk.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                  itemCount: dates.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final date = dates[i];
                    return StaggeredEntrance(
                      animation: _entrance,
                      index: i,
                      child: _DayCard(
                        title: _friendly(date),
                        dateStr: date,
                        future:
                            context.read<HealthProvider>().summaryForDate(date),
                        initiallyOpen: i == 0,
                        onChanged: _refreshHistory,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.title,
    required this.dateStr,
    required this.future,
    required this.initiallyOpen,
    required this.onChanged,
  });

  final String title;
  final String dateStr;
  final Future<DailySummary> future;
  final bool initiallyOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyOpen,
          tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          shape: const RoundedRectangleBorder(),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _dayNumber(dateStr),
                style: t.titleMedium?.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          title: Text(title, style: t.titleMedium),
          iconColor: AppColors.teal,
          collapsedIconColor: AppColors.textSecondary,
          children: [
            FutureBuilder<DailySummary>(
              future: future,
              builder: (context, snap) {
                final s = snap.data;
                if (s == null) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: LinearProgressIndicator(
                        minHeight: 2, color: AppColors.teal),
                  );
                }
                return _DayDetails(summary: s, onChanged: onChanged);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _dayNumber(String date) {
    try {
      return DateTime.parse(date).day.toString();
    } catch (_) {
      return '?';
    }
  }
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.summary, required this.onChanged});
  final DailySummary summary;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final rows = <Widget>[
      for (final m in s.meals)
        _EntryRow(
          icon: Icons.restaurant_menu_rounded,
          iconColor: AppColors.accent,
          title: _cap(m.mealType.name),
          subtitle: m.foodDescription,
          onTap: () => _editMeal(context, m),
          onDelete: () async {
            await context.read<HealthProvider>().deleteMeal(m.id!);
            onChanged();
          },
        ),
      for (final w in s.workouts)
        _EntryRow(
          icon: Icons.fitness_center_rounded,
          iconColor: AppColors.onTrack,
          title: w.exerciseType,
          onTap: () => _editWorkout(context, w),
          onDelete: () async {
            await context.read<HealthProvider>().deleteWorkout(w.id!);
            onChanged();
          },
          subtitle: '${w.durationMinutes} min'
              '${w.notes.isNotEmpty ? ' \u00b7 ${w.notes}' : ''}',
        ),
      if (s.sleep != null)
        _EntryRow(
          icon: Icons.bedtime_rounded,
          iconColor: AppColors.sleep,
          title: 'Sleep',
          onTap: () => _editSleep(context, s.sleep!),
          onDelete: () async {
            await context.read<HealthProvider>().deleteSleep(s.sleep!.id!);
            onChanged();
          },
          subtitle:
              '${s.sleepHours.toStringAsFixed(1)} h  (${s.sleep!.sleepTime}\u2013${s.sleep!.wakeTime})',
        ),
      if (s.steps != null)
        _EntryRow(
          icon: Icons.directions_walk_rounded,
          iconColor: AppColors.teal,
          title: 'Steps',
          subtitle: '${s.steps!.stepCount}',
          onTap: () => _editSteps(context, s.steps!),
          onDelete: () async {
            await context.read<HealthProvider>().deleteSteps(s.steps!.id!);
            onChanged();
          },
        ),
      if (s.weight != null)
        _EntryRow(
          icon: Icons.monitor_weight_rounded,
          iconColor: AppColors.behind,
          title: 'Weight',
          subtitle: '${s.weight!.weightKg.toStringAsFixed(1)} kg',
          onTap: () => _editWeight(context, s.weight!),
          onDelete: () async {
            await context.read<HealthProvider>().deleteWeight(s.weight!.id!);
            onChanged();
          },
        ),
    ];

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('No entries for this day',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary)),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _editMeal(BuildContext context, MealEntry entry) async {
    final description = TextEditingController(text: entry.foodDescription);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${_cap(entry.mealType.name)}'),
        content: TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What did you eat?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true &&
        description.text.trim().isNotEmpty &&
        context.mounted) {
      await context.read<HealthProvider>().updateMeal(entry, description.text);
      onChanged();
    }
    description.dispose();
  }

  Future<void> _editWorkout(BuildContext context, WorkoutEntry entry) async {
    final type = TextEditingController(text: entry.exerciseType);
    final value =
        await _editValue(context, 'Edit workout', type, 'Exercise type');
    if (value != null && value.isNotEmpty && context.mounted) {
      await context
          .read<HealthProvider>()
          .updateWorkout(entry, value, entry.durationMinutes, entry.notes);
      onChanged();
    }
    type.dispose();
  }

  Future<void> _editSleep(BuildContext context, SleepEntry entry) async {
    final value = TextEditingController(text: entry.sleepTime);
    final updated = await _editValue(
        context, 'Edit sleep time', value, 'Sleep time (HH:mm)');
    if (updated != null && context.mounted) {
      try {
        await context
            .read<HealthProvider>()
            .updateSleep(entry, updated, entry.wakeTime);
        onChanged();
      } on FormatException {
        // Keep the original time when the entered value is invalid.
      }
    }
    value.dispose();
  }

  Future<void> _editSteps(BuildContext context, StepsEntry entry) async {
    final value = TextEditingController(text: '${entry.stepCount}');
    final updated = await _editValue(context, 'Edit steps', value, 'Step count',
        keyboardType: TextInputType.number);
    final count = int.tryParse(updated ?? '');
    if (count != null && count >= 0 && context.mounted) {
      await context.read<HealthProvider>().updateSteps(entry, count);
      onChanged();
    }
    value.dispose();
  }

  Future<void> _editWeight(BuildContext context, WeightEntry entry) async {
    final value = TextEditingController(text: '${entry.weightKg}');
    final updated = await _editValue(
        context, 'Edit weight', value, 'Weight in kg',
        keyboardType: const TextInputType.numberWithOptions(decimal: true));
    final kg = double.tryParse(updated ?? '');
    if (kg != null && kg > 0 && context.mounted) {
      await context.read<HealthProvider>().updateWeight(entry, kg);
      onChanged();
    }
    value.dispose();
  }

  Future<String?> _editValue(BuildContext context, String title,
      TextEditingController controller, String hint,
      {TextInputType? keyboardType}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save')),
        ],
      ),
    );
    return saved == true ? controller.text.trim() : null;
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onDelete,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: iconColor, size: 32, iconSize: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: t.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onDelete == null) return content;
    return Dismissible(
      key: ValueKey('$title-$subtitle'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        color: AppColors.behindSoft,
        child:
            const Icon(Icons.delete_outline_rounded, color: AppColors.behind),
      ),
      child: content,
    );
  }
}
