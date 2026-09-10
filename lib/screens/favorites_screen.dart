import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Manage the quick-add meal favorites: add, edit, delete.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> _edit(BuildContext context, {MealFavorite? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    var type = existing?.mealType ?? MealType.snack;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radius)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
              AppSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'New favorite' : 'Edit favorite',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: name,
                decoration:
                    const InputDecoration(hintText: 'Name (e.g. Rice + dal + egg)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                    hintText: 'Description (optional)'),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                children: MealType.values.map((mt) {
                  final active = mt == type;
                  return ChoiceChip(
                    label: Text(mt.name),
                    selected: active,
                    showCheckmark: false,
                    onSelected: (_) => setSheet(() => type = mt),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.accentSoft,
                    side: BorderSide(
                        color:
                            active ? AppColors.accent : AppColors.divider),
                    labelStyle: TextStyle(
                      color: active
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true && name.text.trim().isNotEmpty && context.mounted) {
      final provider = context.read<HealthProvider>();
      if (existing == null) {
        await provider.addFavorite(
            name: name.text, description: desc.text, mealType: type);
      } else {
        await provider.updateFavorite(existing.copyWith(
          name: name.text.trim(),
          description: desc.text.trim(),
          mealType: type,
        ));
      }
    }
    name.dispose();
    desc.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<HealthProvider>().favorites;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New favorite'),
      ),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Meal favorites',
            subtitle: 'One-tap meals for quick logging',
          ),
          Expanded(
            child: favorites.isEmpty
                ? const EmptyState(
                    icon: Icons.star_border_rounded,
                    title: 'No favorites yet',
                    message:
                        'Save meals you eat often — then log them with a\n'
                        'single tap from the Log screen.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, 96),
                    itemCount: favorites.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final fav = favorites[i];
                      return Dismissible(
                        key: ValueKey(fav.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => context
                            .read<HealthProvider>()
                            .deleteFavorite(fav.id!),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.only(right: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.behindSoft,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radius),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.behind),
                        ),
                        child: SoftCard(
                          onTap: () => _edit(context, existing: fav),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              const IconBadge(
                                icon: Icons.restaurant_menu_rounded,
                                color: AppColors.accent,
                                size: 36,
                                iconSize: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(fav.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(
                                      [
                                        fav.mealType.name,
                                        if (fav.description.isNotEmpty)
                                          fav.description,
                                        if (fav.useCount > 0)
                                          'used ${fav.useCount}×',
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color:
                                                  AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary),
                            ],
                          ),
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
