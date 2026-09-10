import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Small uppercase label above a group of inputs.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );
}

/// A −  value  + row inside a soft card. Used for age / height / weight so the
/// user never has to open a keyboard during onboarding.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final String unit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: t.titleMedium),
          ),
          _RoundButton(icon: Icons.remove_rounded, onTap: onMinus),
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 74),
            child: Column(
              children: [
                Text(value,
                    style: t.titleLarge?.copyWith(color: AppColors.teal)),
                Text(unit, style: t.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoundButton(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.teal),
        ),
      ),
    );
  }
}

/// Wrapping set of selectable chips (used for gender).
class ChoiceGrid<T> extends StatelessWidget {
  const ChoiceGrid({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: v == selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(v),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.accentSoft,
            side: BorderSide(
                color: v == selected ? AppColors.accent : AppColors.divider),
            labelStyle: TextStyle(
              color: v == selected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Vertical list of title + subtitle options with a radio-style tick.
class OptionList<T> extends StatelessWidget {
  const OptionList({
    super.key,
    required this.values,
    required this.selected,
    required this.titleOf,
    required this.subtitleOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final v in values) ...[
          SoftCard(
            onTap: () => onChanged(v),
            padding: const EdgeInsets.all(AppSpacing.md),
            color: v == selected ? AppColors.accentSoft : AppColors.surface,
            child: Row(
              children: [
                Icon(
                  v == selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: v == selected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleOf(v), style: t.titleMedium),
                      Text(subtitleOf(v),
                          style: t.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (v != values.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
