import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppAnimations.entranceDuration,
  )..forward();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<HealthProvider>().loadPantry());
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) return;
    await context.read<HealthProvider>().addPantryItem(_name.text, _qty.text);
    if (!mounted) return;
    _name.clear();
    _qty.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _edit(PantryItem item) async {
    final name = TextEditingController(text: item.itemName);
    final qty = TextEditingController(text: item.quantity);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radius)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit item', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: name,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: qty,
              decoration:
                  const InputDecoration(hintText: 'Quantity (optional)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty && mounted) {
      await context.read<HealthProvider>().updatePantryItem(
            item.copyWith(
                itemName: name.text.trim(), quantity: qty.text.trim()),
          );
    }
    name.dispose();
    qty.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    final items = provider.pantry;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Pantry',
            subtitle: items.isEmpty
                ? 'Keep ingredients ready for your next meal'
                : '${items.length} item${items.length == 1 ? '' : 's'} in your kitchen',
            trailing: const AnimatedSparkleIcon(
              icon: Icons.kitchen_rounded,
              size: 24,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: StaggeredEntrance(
              animation: _entrance,
              index: 0,
              child: _AddPantryCard(
                nameController: _name,
                quantityController: _qty,
                onAdd: _add,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.kitchen_rounded,
                    title: 'Your pantry is empty',
                    message:
                        'Add what you have at home so suggestions use\nwhat you can actually cook.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.xs),
                          child: MetaLabel('Your ingredients'),
                        );
                      }
                      final item = items[i - 1];
                      return StaggeredEntrance(
                        animation: _entrance,
                        index: i,
                        child: _PantryTile(
                          item: item,
                          onEdit: () => _edit(item),
                          onToggleLow: (v) => context
                              .read<HealthProvider>()
                              .updatePantryItem(item.copyWith(isLow: v)),
                          onDelete: () => context
                              .read<HealthProvider>()
                              .deletePantryItem(item.id!),
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

class _AddPantryCard extends StatelessWidget {
  const _AddPantryCard({
    required this.nameController,
    required this.quantityController,
    required this.onAdd,
  });

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add an ingredient', style: t.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Use it to make your meal suggestions more useful.',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(hintText: 'Item name (e.g. rice)'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: quantityController,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(hintText: 'Quantity'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: nameController.text.trim().isEmpty ? null : onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add to pantry'),
          ),
        ],
      ),
    );
  }
}

class _PantryTile extends StatelessWidget {
  const _PantryTile({
    required this.item,
    required this.onEdit,
    required this.onToggleLow,
    required this.onDelete,
  });

  final PantryItem item;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleLow;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey(item.id),
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
        onTap: onEdit,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    item.isLow ? AppColors.behindSoft : AppColors.onTrackSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.isLow ? Icons.inventory_2_outlined : Icons.kitchen_rounded,
                color: item.isLow ? AppColors.behind : AppColors.onTrack,
                size: 21,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.itemName, style: t.titleMedium),
                  if (item.quantity.isNotEmpty)
                    Text(item.quantity,
                        style: t.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            _LowToggle(value: item.isLow, onChanged: onToggleLow),
          ],
        ),
      ),
    );
  }
}

class _LowToggle extends StatelessWidget {
  const _LowToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.error_rounded : Icons.check_circle_outline_rounded,
              size: 18,
              color: value ? AppColors.behind : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              value ? 'Low' : 'OK',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: value ? AppColors.behind : AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
