import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../services/health_steps_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/voice_mic_button.dart';
import 'favorites_screen.dart';
import 'meal_routine_screen.dart';

class LogEntryScreen extends StatefulWidget {
  const LogEntryScreen({
    super.key,
    this.initialTab = 0,
    this.autoStartVoice = false,
    this.popOnSave = false,
  });

  /// Which pill is selected on open — see [_LogEntryScreenState._labels].
  final int initialTab;

  /// Starts the meal tab's mic listening automatically once the screen is up
  /// — used by the "log it" / "something else" routine-suggestion banner.
  final bool autoStartVoice;

  /// Whether to pop this screen off the navigation stack after saving.
  final bool popOnSave;

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  late int _tab = widget.initialTab;

  static const _labels = ['Meal', 'Workout', 'Sleep', 'Weight', 'Steps'];
  static const _icons = [
    Icons.restaurant_rounded,
    Icons.fitness_center_rounded,
    Icons.bedtime_rounded,
    Icons.monitor_weight_rounded,
    Icons.directions_walk_rounded,
  ];

  Future<void> _afterSave() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black12,
      builder: (_) => const _SavedFlash(),
    );
    if (!mounted) return;
    final suggestion = context.read<HealthProvider>().pendingTemplateSuggestion;
    if (suggestion == null) return;
    context.read<HealthProvider>().clearTemplateSuggestion();
    final wantsToSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.repeat_rounded, color: AppColors.teal, size: 32),
        title: const Text('Save as routine?'),
        content: Text(suggestion.message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add it')),
        ],
      ),
    );
    if (wantsToSave == true && mounted) {
      await showAddTemplateSheet(
        context,
        initialSlot: suggestion.mealType,
        initialDescription: suggestion.description,
      );
    }
    if (widget.popOnSave && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
            _LogHeader(
              labels: _labels,
              icons: _icons,
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _MealForm(
                      onSaved: _afterSave, autoStartVoice: widget.autoStartVoice),
                  _WorkoutForm(onSaved: _afterSave),
                  _SleepForm(onSaved: _afterSave),
                  _WeightForm(onSaved: _afterSave),
                  _StepsForm(onSaved: _afterSave),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LOG HEADER WITH PILLS ──────────────────────────────────────────────────

class _LogHeader extends StatelessWidget {
  const _LogHeader({
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Log an entry',
                    style: t.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Segmented pills
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: labels.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final active = i == selected;
                    return GestureDetector(
                      onTap: () => onChanged(i),
                      child: AnimatedContainer(
                        duration: AppAnimations.microDuration,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icons[i],
                              size: 16,
                              color: active
                                  ? AppColors.teal
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              labels[i],
                              style: t.labelLarge?.copyWith(
                                color: active
                                    ? AppColors.teal
                                    : Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared form scaffolding
// ---------------------------------------------------------------------------

/// Body + sticky full-width save button, with a disabled state and loading spinner.
class _FormScaffold extends StatefulWidget {
  const _FormScaffold({
    required this.fields,
    required this.saveLabel,
    required this.canSave,
    required this.onSave,
  });

  final List<Widget> fields;
  final String saveLabel;
  final bool canSave;
  final Future<void> Function() onSave;

  @override
  State<_FormScaffold> createState() => _FormScaffoldState();
}

class _FormScaffoldState extends State<_FormScaffold> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
            children: [
              for (final f in widget.fields) ...[
                f,
                const SizedBox(height: AppSpacing.lg),
              ],
              const _TodayLogHistory(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: (widget.canSave && !_saving)
                  ? () async {
                      setState(() => _saving = true);
                      try {
                        await widget.onSave();
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    }
                  : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.saveLabel),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live record of today's entries, kept in the logging flow so a user can
/// confirm an entry before adding another one.
class _TodayLogHistory extends StatelessWidget {
  const _TodayLogHistory();

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<HealthProvider>().today;
    if (summary == null) return const SizedBox.shrink();

    final rows = <_TodayHistoryRow>[
      for (final meal in summary.meals)
        _TodayHistoryRow(
          icon: Icons.restaurant_menu_rounded,
          color: AppColors.accent,
          title: _capitalize(meal.mealType.name),
          subtitle: meal.foodDescription,
          meal: meal,
        ),
      for (final workout in summary.workouts)
        _TodayHistoryRow(
          icon: Icons.fitness_center_rounded,
          color: AppColors.onTrack,
          title: workout.exerciseType,
          subtitle: '${workout.durationMinutes} min'
              '${workout.notes.isEmpty ? '' : ' · ${workout.notes}'}',
        ),
      if (summary.sleep != null)
        _TodayHistoryRow(
          icon: Icons.bedtime_rounded,
          color: AppColors.sleep,
          title: 'Sleep',
          subtitle: '${summary.sleepHours.toStringAsFixed(1)} hours',
        ),
      if (summary.steps != null)
        _TodayHistoryRow(
          icon: Icons.directions_walk_rounded,
          color: AppColors.teal,
          title: 'Steps',
          subtitle: '${summary.stepCount} steps',
        ),
      if (summary.weight != null)
        _TodayHistoryRow(
          icon: Icons.monitor_weight_rounded,
          color: AppColors.behind,
          title: 'Weight',
          subtitle: '${summary.weight!.weightKg.toStringAsFixed(1)} kg',
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaLabel("Today's history"),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                    icon: rows[i].icon,
                    color: rows[i].color,
                    size: 32,
                    iconSize: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].title, style: t.titleMedium),
                      Text(rows[i].subtitle,
                          style: t.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (rows[i].meal != null)
                  _FavoriteStar(meal: rows[i].meal!),
              ],
            ),
            if (i != rows.length - 1) ...[
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

class _TodayHistoryRow {
  const _TodayHistoryRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.meal,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// Set for meal rows — enables the "save as favorite" star.
  final MealEntry? meal;
}

/// Star toggle that saves a logged meal as a quick-add favorite.
class _FavoriteStar extends StatelessWidget {
  const _FavoriteStar({required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final saved = provider.isFavorite(meal.foodDescription);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: saved ? 'Already a favorite' : 'Save as favorite',
      onPressed: saved
          ? null
          : () async {
              await context.read<HealthProvider>().favoriteFromMeal(meal);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to favorites')),
                );
              }
            },
      icon: Icon(
        saved ? Icons.star_rounded : Icons.star_border_rounded,
        color: saved ? AppColors.accent : AppColors.textSecondary,
        size: 20,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.icon});
  final String label;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              IconBadge(icon: icon!, size: 28, iconSize: 14),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: t.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

/// Brief centered checkmark with scale up, hold, and fade animation.
class _SavedFlash extends StatefulWidget {
  const _SavedFlash();
  @override
  State<_SavedFlash> createState() => _SavedFlashState();
}

class _SavedFlashState extends State<_SavedFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    ),
  );
  late final Animation<double> _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _fade.value,
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            boxShadow: kSoftShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.onTrack.withValues(alpha: 0.15),
                      AppColors.onTrackSoft,
                    ],
                  ),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 28, color: AppColors.onTrack),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Saved!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual forms
// ---------------------------------------------------------------------------

class _MealForm extends StatefulWidget {
  const _MealForm({required this.onSaved, this.autoStartVoice = false});
  final Future<void> Function() onSaved;
  final bool autoStartVoice;
  @override
  State<_MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<_MealForm> {
  MealType _type = MealType.breakfast;
  final _desc = TextEditingController();
  final _micKey = GlobalKey<VoiceMicButtonState>();
  bool _parsingVoice = false;

  @override
  void initState() {
    super.initState();
    _desc.addListener(() => setState(() {}));
    if (widget.autoStartVoice) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _micKey.currentState?.start());
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  /// The mic hands back a raw transcript; ask Gemini to structure it, then
  /// pre-fill the form. A parse failure just drops the raw words into the
  /// text field so the user can clean it up manually — one tap either way.
  Future<void> _onTranscript(String transcript) async {
    if (transcript.trim().isEmpty) return;
    setState(() => _parsingVoice = true);
    final parsed = await context.read<HealthProvider>().parseVoiceMeal(transcript);
    if (!mounted) return;
    setState(() {
      _parsingVoice = false;
      if (parsed != null) {
        _type = parsed.mealType;
        _desc.text = parsed.foodDescription;
      } else {
        _desc.text = transcript;
      }
    });
  }

  Future<void> _saveAsFavorite() async {
    if (_desc.text.trim().isEmpty) return;
    await context
        .read<HealthProvider>()
        .addFavorite(name: _desc.text, mealType: _type);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to favorites')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<HealthProvider>().favorites;
    return _FormScaffold(
      saveLabel: 'Save meal',
      canSave: _desc.text.trim().isNotEmpty,
      onSave: () async {
        await context.read<HealthProvider>().addMeal(_type, _desc.text);
        _desc.clear();
        await widget.onSaved();
      },
      fields: [
        Center(
          child: _parsingVoice
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: AppColors.teal)),
                      SizedBox(height: AppSpacing.xs),
                      Text('Making sense of that…'),
                    ],
                  ),
                )
              : VoiceMicButton(key: _micKey, onTranscript: _onTranscript),
        ),
        if (favorites.isNotEmpty)
          _MealFavoritesRow(
            favorites: favorites,
            onTap: (fav) async {
              await context.read<HealthProvider>().logFavorite(fav);
              await widget.onSaved();
            },
          ),
        _Field(
          label: 'Meal type',
          icon: Icons.restaurant_rounded,
          child: Wrap(
            spacing: AppSpacing.xs,
            children: MealType.values.map((mt) {
              final active = mt == _type;
              return ChoiceChip(
                label: Text(mt.name),
                selected: active,
                showCheckmark: false,
                onSelected: (_) => setState(() => _type = mt),
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.accentSoft,
                side: BorderSide(
                    color: active ? AppColors.accent : AppColors.divider),
                labelStyle: TextStyle(
                  color: active ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        _Field(
          label: 'What did you eat?',
          icon: Icons.edit_rounded,
          child: TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'e.g. Oats with banana and peanut butter'),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _desc.text.trim().isEmpty ? null : _saveAsFavorite,
            icon: const Icon(Icons.star_border_rounded, size: 18),
            label: const Text('Save as favorite'),
          ),
        ),
      ],
    );
  }
}

/// Horizontal one-tap quick-add row shown above the meal fields.
class _MealFavoritesRow extends StatelessWidget {
  const _MealFavoritesRow({required this.favorites, required this.onTap});
  final List<MealFavorite> favorites;
  final Future<void> Function(MealFavorite) onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const MetaLabel('Quick add'),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FavoritesScreen())),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, i) {
              final fav = favorites[i];
              return ActionChip(
                avatar: const Icon(Icons.add_rounded,
                    size: 16, color: AppColors.accent),
                label: Text(fav.name),
                onPressed: () => onTap(fav),
                backgroundColor: AppColors.accentSoft,
                side: const BorderSide(color: AppColors.accentSoft),
                labelStyle: t.labelLarge?.copyWith(color: AppColors.accent),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkoutForm extends StatefulWidget {
  const _WorkoutForm({required this.onSaved});
  final Future<void> Function() onSaved;
  @override
  State<_WorkoutForm> createState() => _WorkoutFormState();
}

class _WorkoutFormState extends State<_WorkoutForm> {
  final _type = TextEditingController();
  final _mins = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_type, _mins]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _type.dispose();
    _mins.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = int.tryParse(_mins.text.trim());
    return _FormScaffold(
      saveLabel: 'Save workout',
      canSave: _type.text.trim().isNotEmpty && mins != null && mins > 0,
      onSave: () async {
        await context
            .read<HealthProvider>()
            .addWorkout(_type.text, mins!, _notes.text);
        _type.clear();
        _mins.clear();
        _notes.clear();
        await widget.onSaved();
      },
      fields: [
        _Field(
          label: 'Exercise type',
          icon: Icons.fitness_center_rounded,
          child: TextField(
            controller: _type,
            decoration:
                const InputDecoration(hintText: 'e.g. Upper body, Running'),
          ),
        ),
        _Field(
          label: 'Duration (minutes)',
          icon: Icons.timer_rounded,
          child: TextField(
            controller: _mins,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 45'),
          ),
        ),
        _Field(
          label: 'Notes (optional)',
          icon: Icons.note_alt_rounded,
          child: TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'How did it feel?'),
          ),
        ),
      ],
    );
  }
}

class _SleepForm extends StatefulWidget {
  const _SleepForm({required this.onSaved});
  final Future<void> Function() onSaved;
  @override
  State<_SleepForm> createState() => _SleepFormState();
}

class _SleepFormState extends State<_SleepForm> {
  TimeOfDay _sleep = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isSleep) async {
    final v = await showTimePicker(
      context: context,
      initialTime: isSleep ? _sleep : _wake,
    );
    if (v != null) setState(() => isSleep ? _sleep = v : _wake = v);
  }

  @override
  Widget build(BuildContext context) {
    final hours = SleepEntry.hoursBetween(_fmt(_sleep), _fmt(_wake));
    return _FormScaffold(
      saveLabel: 'Save sleep',
      canSave: true,
      onSave: () async {
        await context
            .read<HealthProvider>()
            .addSleep(_fmt(_sleep), _fmt(_wake));
        await widget.onSaved();
      },
      fields: [
        Row(
          children: [
            Expanded(
              child: _TimeCard(
                label: 'Slept at',
                value: _fmt(_sleep),
                icon: Icons.bedtime_rounded,
                iconColor: AppColors.sleep,
                onTap: () => _pick(true),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TimeCard(
                label: 'Woke at',
                value: _fmt(_wake),
                icon: Icons.wb_sunny_rounded,
                iconColor: AppColors.behind,
                onTap: () => _pick(false),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.onTrackSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            boxShadow: kSoftShadow,
          ),
          child: Row(
            children: [
              const IconBadge(
                icon: Icons.nightlight_round,
                color: AppColors.onTrack,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('${hours.toStringAsFixed(1)} hours of sleep',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: iconColor, size: 28, iconSize: 14),
              const SizedBox(width: AppSpacing.xs),
              Text(label,
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _WeightForm extends StatefulWidget {
  const _WeightForm({required this.onSaved});
  final Future<void> Function() onSaved;
  @override
  State<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<_WeightForm> {
  final _kg = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kg.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kg = double.tryParse(_kg.text.trim());
    return _FormScaffold(
      saveLabel: 'Save weight',
      canSave: kg != null && kg > 0,
      onSave: () async {
        await context.read<HealthProvider>().addWeight(kg!);
        _kg.clear();
        await widget.onSaved();
      },
      fields: [
        _Field(
          label: 'Weight (kg)',
          icon: Icons.monitor_weight_rounded,
          child: TextField(
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'e.g. 68.5'),
          ),
        ),
      ],
    );
  }
}

class _StepsForm extends StatefulWidget {
  const _StepsForm({required this.onSaved});
  final Future<void> Function() onSaved;
  @override
  State<_StepsForm> createState() => _StepsFormState();
}

class _StepsFormState extends State<_StepsForm> {
  final _steps = TextEditingController();
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _steps.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _steps.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    final ok = await context.read<HealthProvider>().connectHealthData();
    if (!mounted) return;
    setState(() => _connecting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Connected — your steps sync automatically now'
          : 'Health data access was not granted. You can still enter steps '
              'manually.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final n = int.tryParse(_steps.text.trim());
    final autoTracked = provider.stepsAutoTracked;
    final todaySteps = provider.today?.steps?.stepCount;

    return _FormScaffold(
      saveLabel: 'Save steps',
      canSave: n != null && n >= 0,
      onSave: () async {
        await context.read<HealthProvider>().addSteps(n!);
        _steps.clear();
        await widget.onSaved();
      },
      fields: [
        if (autoTracked)
          _AutoStepsCard(
            todaySteps: todaySteps,
            onRefresh: () =>
                context.read<HealthProvider>().refreshStepsFromHealth(),
          )
        else
          _ConnectHealthCard(
            busy: _connecting,
            unavailable:
                provider.healthAccess == HealthAccess.unavailable,
            onConnect: _connect,
          ),
        _Field(
          label: autoTracked ? 'Or enter manually' : 'Step count',
          icon: Icons.directions_walk_rounded,
          child: TextField(
            controller: _steps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 6200'),
          ),
        ),
      ],
    );
  }
}

class _AutoStepsCard extends StatelessWidget {
  const _AutoStepsCard({required this.todaySteps, required this.onRefresh});
  final int? todaySteps;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.onTrackSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.watch_rounded,
            color: AppColors.onTrack,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-tracked from health data', style: t.titleMedium),
                Text(
                  todaySteps == null
                      ? 'Syncing today’s steps…'
                      : "Today: $todaySteps steps",
                  style: t.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sync now',
            onPressed: onRefresh,
            icon: const Icon(Icons.sync_rounded, color: AppColors.onTrack),
          ),
        ],
      ),
    );
  }
}

class _ConnectHealthCard extends StatelessWidget {
  const _ConnectHealthCard({
    required this.busy,
    required this.unavailable,
    required this.onConnect,
  });
  final bool busy;
  final bool unavailable;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.favorite_rounded,
                color: AppColors.teal,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  unavailable
                      ? 'Health data isn’t available on this device'
                      : 'Connect health data',
                  style: t.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            unavailable
                ? 'Enter your steps manually below.'
                : 'Let Stock Plate read your step count so you don’t have to '
                    'type it in.',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (!unavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: busy ? null : onConnect,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link_rounded, size: 18),
              label: Text(busy ? 'Connecting…' : 'Connect'),
            ),
          ],
        ],
      ),
    );
  }
}
