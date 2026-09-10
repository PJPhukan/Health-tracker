import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Past AI suggestions, newest first, grouped by day. Expandable cards.
class SuggestionHistoryScreen extends StatefulWidget {
  const SuggestionHistoryScreen({super.key});

  @override
  State<SuggestionHistoryScreen> createState() =>
      _SuggestionHistoryScreenState();
}

class _SuggestionHistoryScreenState extends State<SuggestionHistoryScreen> {
  late Future<List<SuggestionEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<HealthProvider>().suggestionHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Past suggestions',
            subtitle: 'Everything the AI has suggested for you',
          ),
          Expanded(
            child: FutureBuilder<List<SuggestionEntry>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.teal));
                }
                final entries = snap.data!;
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Nothing yet',
                    message: 'Your suggestion history will appear here.',
                  );
                }
                final groups = _groupByDay(entries);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                  itemCount: groups.length,
                  itemBuilder: (context, i) => _DayGroup(
                    label: groups[i].label,
                    entries: groups[i].entries,
                    initiallyOpen: i == 0,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<({String label, List<SuggestionEntry> entries})> _groupByDay(
      List<SuggestionEntry> entries) {
    final byDate = <String, List<SuggestionEntry>>{};
    for (final e in entries) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys) (label: _friendlyDate(k), entries: byDate[k]!),
    ];
  }

  static String _friendlyDate(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(d);
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.label,
    required this.entries,
    required this.initiallyOpen,
  });

  final String label;
  final List<SuggestionEntry> entries;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Text(label.toUpperCase(), style: t.labelSmall),
        ),
        for (final e in entries) ...[
          _SuggestionHistoryCard(entry: e, initiallyOpen: initiallyOpen),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SuggestionHistoryCard extends StatefulWidget {
  const _SuggestionHistoryCard({
    required this.entry,
    required this.initiallyOpen,
  });

  final SuggestionEntry entry;
  final bool initiallyOpen;

  @override
  State<_SuggestionHistoryCard> createState() => _SuggestionHistoryCardState();
}

class _SuggestionHistoryCardState extends State<_SuggestionHistoryCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = widget.entry;
    final time = _time(e.timestamp);
    final context_ = _mealContext(e.prompt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.accent,
                    size: 34,
                    iconSize: 17,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time, style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          context_ ?? 'Based on your day’s log',
                          maxLines: _open ? null : 1,
                          overflow: _open ? null : TextOverflow.ellipsis,
                          style: t.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  e.response.trim(),
                  style: t.bodyLarge?.copyWith(height: 1.55),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _time(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? '' : DateFormat('h:mm a').format(d);
  }

  /// Pull the "- Meals: ..." line out of the stored prompt for a one-line
  /// summary of what the suggestion was based on.
  static String? _mealContext(String prompt) {
    for (final line in prompt.split('\n')) {
      final m = RegExp(r'^\s*-\s*Meals:\s*(.+)$').firstMatch(line);
      if (m != null) {
        final v = m.group(1)!.trim();
        if (v.isEmpty || v.toLowerCase().contains('nothing logged')) {
          return 'No meals logged that day';
        }
        return 'After: $v';
      }
    }
    return null;
  }
}
