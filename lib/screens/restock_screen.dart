import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Quick "I just went shopping" screen: tick what you bought, tap once, and
/// every ticked item flips back to in-stock. Reachable from the Pantry
/// screen's top-right action and from a "Buy today" suggestion card.
class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key, this.suggestedNames});

  /// Item names pulled from a "Buy today" suggestion — pre-ticked, and
  /// offered as new pantry entries if they aren't in the pantry at all yet.
  final List<String>? suggestedNames;

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _checkedLow = <int>{};
  final _checkedNew = <String>{};
  bool _saving = false;

  bool _matchesSuggestion(String itemName) {
    final suggested = widget.suggestedNames;
    if (suggested == null) return false;
    final n = itemName.toLowerCase();
    return suggested.any((s) => n.contains(s.toLowerCase()) || s.toLowerCase().contains(n));
  }

  List<String> _newFromSuggestions(List<PantryItem> pantry) {
    final suggested = widget.suggestedNames;
    if (suggested == null) return const [];
    final existing = pantry.map((p) => p.itemName.toLowerCase()).toSet();
    return suggested.where((s) => !existing.contains(s.toLowerCase())).toList();
  }

  void _initSelectionOnce(List<PantryItem> lowItems, List<String> newItems) {
    if (widget.suggestedNames == null) return;
    for (final item in lowItems) {
      if (_matchesSuggestion(item.itemName)) _checkedLow.add(item.id!);
    }
    _checkedNew.addAll(newItems);
  }

  Future<void> _confirm(List<PantryItem> lowItems) async {
    setState(() => _saving = true);
    final provider = context.read<HealthProvider>();
    for (final item in lowItems) {
      if (_checkedLow.contains(item.id)) {
        await provider.updatePantryItem(item.copyWith(isLow: false));
      }
    }
    for (final name in _checkedNew) {
      await provider.addPantryItem(name, '');
    }
    if (!mounted) return;
    setState(() => _saving = false);
    final count = _checkedLow.length + _checkedNew.length;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count == 0
          ? 'Nothing marked as restocked'
          : 'Restocked $count item${count == 1 ? '' : 's'}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<HealthProvider>().pantry;
    final lowItems = pantry.where((p) => p.isLow).toList();
    final newItems = _newFromSuggestions(pantry);
    if (_checkedLow.isEmpty && _checkedNew.isEmpty) {
      _initSelectionOnce(lowItems, newItems);
    }
    final total = _checkedLow.length + _checkedNew.length;

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Restock',
            subtitle: 'Tick what you bought',
          ),
          Expanded(
            child: lowItems.isEmpty && newItems.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Nothing to restock',
                    message: 'Everything in your pantry is marked in stock.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                    children: [
                      if (lowItems.isNotEmpty) ...[
                        const MetaLabel('Running low'),
                        const SizedBox(height: AppSpacing.xs),
                        for (final item in lowItems)
                          _RestockTile(
                            title: item.itemName,
                            subtitle: item.quantity,
                            checked: _checkedLow.contains(item.id),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _checkedLow.add(item.id!);
                              } else {
                                _checkedLow.remove(item.id);
                              }
                            }),
                          ),
                      ],
                      if (newItems.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        const MetaLabel('New from your suggestion'),
                        const SizedBox(height: AppSpacing.xs),
                        for (final name in newItems)
                          _RestockTile(
                            title: name,
                            subtitle: 'Not in your pantry yet',
                            checked: _checkedNew.contains(name),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _checkedNew.add(name);
                              } else {
                                _checkedNew.remove(name);
                              }
                            }),
                          ),
                      ],
                    ],
                  ),
          ),
          if (lowItems.isNotEmpty || newItems.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
                child: FilledButton(
                  onPressed: _saving ? null : () => _confirm(lowItems),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : Text(total == 0
                          ? 'Mark restocked'
                          : 'Mark $total restocked'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RestockTile extends StatelessWidget {
  const _RestockTile({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SoftCard(
        onTap: () => onChanged(!checked),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.onTrack,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
