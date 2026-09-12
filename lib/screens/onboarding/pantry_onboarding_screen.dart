import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/pantry_presets.dart';
import '../../providers/health_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// A fast first-run pantry setup: an 80-item checklist instead of typing
/// items one at a time. Also reachable from Settings as "Rebuild pantry
/// checklist" for returning users.
class PantryOnboardingScreen extends StatefulWidget {
  const PantryOnboardingScreen({
    super.key,
    this.isFirstRun = false,
    this.onFirstRunDone,
  });

  /// True when shown straight from the onboarding gate (not pushed on a
  /// navigator) — in that case completion is signalled via
  /// [onFirstRunDone] instead of a Navigator pop.
  final bool isFirstRun;
  final VoidCallback? onFirstRunDone;

  @override
  State<PantryOnboardingScreen> createState() =>
      _PantryOnboardingScreenState();
}

class _PantryOnboardingScreenState extends State<PantryOnboardingScreen> {
  final _checked = <String>{};
  final _customBySection = <String, List<String>>{};
  final _search = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> _itemsFor(PantrySection section) =>
      [...section.items, ...?_customBySection[section.title]];

  List<String> _filtered(List<String> items) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) => i.toLowerCase().contains(q)).toList();
  }

  void _toggle(String item) => setState(() {
        if (!_checked.add(item)) _checked.remove(item);
      });

  void _toggleSection(List<String> visibleItems) => setState(() {
        final allSelected = visibleItems.every(_checked.contains);
        if (allSelected) {
          _checked.removeAll(visibleItems);
        } else {
          _checked.addAll(visibleItems);
        }
      });

  Future<void> _addCustom(String sectionTitle, String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    setState(() {
      (_customBySection[sectionTitle] ??= []).add(name);
      _checked.add(name);
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final added =
        await context.read<HealthProvider>().addPantryItemsBatch(_checked.toList());
    if (!mounted) return;
    setState(() => _saving = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.kitchen_rounded, color: AppColors.teal, size: 32),
        title: const Text('Pantry ready'),
        content: Text(added == 0
            ? 'No new items were added — your pantry already has these.'
            : 'Your pantry is set up with $added item${added == 1 ? '' : 's'}. '
                'Stock Plate will suggest meals from these.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Great')),
        ],
      ),
    );
    if (!mounted) return;
    if (widget.isFirstRun) {
      widget.onFirstRunDone?.call();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          GradientHeader(
            title: 'What\'s in your kitchen?',
            subtitle: widget.isFirstRun
                ? 'Tap what you have — skip the rest'
                : 'Add anything new to your pantry',
            leading: widget.isFirstRun ? const SizedBox.shrink() : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search ingredients…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
              children: [
                for (final section in pantryPresets)
                  Builder(builder: (context) {
                    final visible = _filtered(_itemsFor(section));
                    if (visible.isEmpty) return const SizedBox.shrink();
                    return _SectionCard(
                      section: section,
                      visibleItems: visible,
                      checked: _checked,
                      onToggleItem: _toggle,
                      onToggleAll: () => _toggleSection(visible),
                      onAddCustom: (name) => _addCustom(section.title, name),
                    );
                  }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_checked.length} item${_checked.length == 1 ? '' : 's'} selected',
                      style: t.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _saving ? null : _finish,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.visibleItems,
    required this.checked,
    required this.onToggleItem,
    required this.onToggleAll,
    required this.onAddCustom,
  });

  final PantrySection section;
  final List<String> visibleItems;
  final Set<String> checked;
  final ValueChanged<String> onToggleItem;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onAddCustom;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final allSelected = visibleItems.every(checked.contains);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SoftCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(section.title, style: t.titleMedium)),
                TextButton(
                  onPressed: onToggleAll,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(allSelected ? 'Clear all' : 'Select all'),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                for (final item in visibleItems)
                  FilterChip(
                    label: Text(item),
                    selected: checked.contains(item),
                    onSelected: (_) => onToggleItem(item),
                    showCheckmark: true,
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.onTrackSoft,
                    side: BorderSide(
                        color: checked.contains(item)
                            ? AppColors.onTrack
                            : AppColors.divider),
                    labelStyle: TextStyle(
                      color: checked.contains(item)
                          ? AppColors.onTrack
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _AddCustomRow(onAdd: onAddCustom),
          ],
        ),
      ),
    );
  }
}

class _AddCustomRow extends StatefulWidget {
  const _AddCustomRow({required this.onAdd});
  final ValueChanged<String> onAdd;

  @override
  State<_AddCustomRow> createState() => _AddCustomRowState();
}

class _AddCustomRowState extends State<_AddCustomRow> {
  final _controller = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onAdd(_controller.text);
    _controller.clear();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add custom item'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'Item name'),
          ),
        ),
        IconButton(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded, color: AppColors.onTrack),
        ),
      ],
    );
  }
}
