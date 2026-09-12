import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Settings -> "My meal routine": the recurring meals that power the Home
/// screen's "log it?" banner. Multiple templates per slot are fine — the
/// first one matching today's day type wins.
class MealRoutineScreen extends StatelessWidget {
  const MealRoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<HealthProvider>().templates;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTemplateSheet(context),
        tooltip: 'Add a routine meal',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          const GradientHeader(
            title: 'My meal routine',
            subtitle: 'What you usually eat — swipe to remove',
          ),
          Expanded(
            child: templates.isEmpty
                ? const EmptyState(
                    icon: Icons.repeat_rounded,
                    title: 'No routine meals yet',
                    message: 'Add the meals you eat on repeat and Stock '
                        'Plate will offer to log them for you.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                    itemCount: templates.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _TemplateTile(
                      template: templates[i],
                      onDelete: () => context
                          .read<HealthProvider>()
                          .deleteTemplate(templates[i].id!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onDelete});
  final MealTemplate template;
  final VoidCallback onDelete;

  String _dayLabel(DayType d) => switch (d) {
        DayType.weekday => 'Weekdays',
        DayType.weekend => 'Weekends',
        DayType.everyday => 'Every day',
      };

  IconData _slotIcon(MealType m) => switch (m) {
        MealType.breakfast => Icons.wb_sunny_rounded,
        MealType.lunch => Icons.lunch_dining_rounded,
        MealType.dinner => Icons.dinner_dining_rounded,
        MealType.snack => Icons.cookie_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey(template.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.behindSoft,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child:
            const Icon(Icons.delete_outline_rounded, color: AppColors.behind),
      ),
      child: SoftCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconBadge(icon: _slotIcon(template.mealSlot), size: 40, iconSize: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_dayLabel(template.dayType)} · '
                    '${template.mealSlot.name[0].toUpperCase()}${template.mealSlot.name.substring(1)}',
                    style: t.labelSmall,
                  ),
                  Text(template.foodDescription, style: t.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reused by the routine screen's FAB and by the post-save "Save as routine?"
/// prompt (see log_entry_screen.dart).
Future<void> showAddTemplateSheet(
  BuildContext context, {
  MealType? initialSlot,
  String? initialDescription,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radius)),
    ),
    builder: (ctx) => _TemplateFormSheet(
      initialSlot: initialSlot,
      initialDescription: initialDescription,
    ),
  );
}

class _TemplateFormSheet extends StatefulWidget {
  const _TemplateFormSheet({this.initialSlot, this.initialDescription});
  final MealType? initialSlot;
  final String? initialDescription;

  @override
  State<_TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends State<_TemplateFormSheet> {
  late DayType _dayType = DayType.weekday;
  late MealType _slot = widget.initialSlot ?? MealType.breakfast;
  late final _desc =
      TextEditingController(text: widget.initialDescription ?? '');

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_desc.text.trim().isEmpty) return;
    await context.read<HealthProvider>().addTemplate(
          dayType: _dayType,
          mealSlot: _slot,
          description: _desc.text,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
          AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a routine meal', style: t.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text('When', style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final d in DayType.values)
                ChoiceChip(
                  label: Text(switch (d) {
                    DayType.weekday => 'Weekdays',
                    DayType.weekend => 'Weekends',
                    DayType.everyday => 'Every day',
                  }),
                  selected: _dayType == d,
                  onSelected: (_) => setState(() => _dayType = d),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Meal', style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final m in MealType.values)
                ChoiceChip(
                  label: Text(m.name),
                  selected: _slot == m,
                  onSelected: (_) => setState(() => _slot = m),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('What do you usually eat?', style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration:
                const InputDecoration(hintText: 'e.g. Rice + dal + egg'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Save routine')),
        ],
      ),
    );
  }
}
