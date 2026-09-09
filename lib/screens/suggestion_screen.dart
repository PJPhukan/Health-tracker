import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SuggestionScreen extends StatelessWidget {
  const SuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthProvider>();
    return Scaffold(
      body: _body(context, provider),
    );
  }

  Widget _body(BuildContext context, HealthProvider provider) {
    switch (provider.suggestionStatus) {
      case SuggestionStatus.loading:
        return const _LoadingView();
      case SuggestionStatus.error:
        return _ErrorView(errorMessage: provider.suggestionError);
      case SuggestionStatus.success:
        return _SuccessView(text: provider.suggestionText ?? '');
      case SuggestionStatus.idle:
        return const _IdleView();
    }
  }
}

// ─── LOADING VIEW ───────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: AppAnimations.shimmerDuration,
  )..repeat();

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        const GradientHeader(
          title: 'AI Suggestion',
          subtitle: 'Analyzing your health data\u2026',
          trailing: AnimatedSparkleIcon(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _PulsingBrainIcon(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Thinking about your day\u2026',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Reading today\u0027s meals, sleep & steps',
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ShimmerBlock(
                    controller: _shimmerController,
                    width: double.infinity,
                    height: 18),
                const SizedBox(height: AppSpacing.sm),
                ShimmerBlock(
                    controller: _shimmerController, width: 260, height: 18),
                const SizedBox(height: AppSpacing.sm),
                ShimmerBlock(
                    controller: _shimmerController, width: 200, height: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingBrainIcon extends StatefulWidget {
  const _PulsingBrainIcon();

  @override
  State<_PulsingBrainIcon> createState() => _PulsingBrainIconState();
}

class _PulsingBrainIconState extends State<_PulsingBrainIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = CurvedAnimation(parent: _c, curve: Curves.easeInOut).value;
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.lerp(AppColors.tealLight, AppColors.teal, v)!,
                Color.lerp(AppColors.teal, AppColors.tealLight, v)!
                    .withValues(alpha: 0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealLight.withValues(alpha: 0.3 + 0.15 * v),
                blurRadius: 24 + 12 * v,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Transform.scale(
            scale: 0.9 + 0.1 * v,
            child: const Icon(
              Icons.psychology_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// ─── SUCCESS VIEW ───────────────────────────────────────────────────────────

class _SuccessView extends StatefulWidget {
  const _SuccessView({required this.text});
  final String text;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppAnimations.entranceDuration,
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sections = _parseSuggestion(widget.text);

    return Column(
      children: [
        const GradientHeader(
          title: 'Your Suggestion',
          subtitle: 'Personalized just for you',
          trailing: AnimatedSparkleIcon(),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
            itemCount: sections.length + 1,
            itemBuilder: (context, index) {
              if (index == sections.length) {
                return StaggeredEntrance(
                  animation: _entrance,
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _RefreshButton(
                      onPressed: () =>
                          context.read<HealthProvider>().getSuggestion(),
                    ),
                  ),
                );
              }

              final section = sections[index];
              return StaggeredEntrance(
                animation: _entrance,
                index: index,
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: index < sections.length - 1 ? AppSpacing.sm : 0),
                  child: _SuggestionCard(section: section, textTheme: t),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.section, required this.textTheme});
  final _SuggestionSection section;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final hasIcon = section.icon != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
        border: section.accentColor != null
            ? Border(
                left: BorderSide(color: section.accentColor!, width: 3.5),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.heading != null) ...[
            Row(
              children: [
                if (hasIcon) ...[
                  IconBadge(
                    icon: section.icon!,
                    color: section.accentColor ?? AppColors.teal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    section.heading!,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            section.body,
            style: textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md, horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const IconBadge(
                icon: Icons.refresh_rounded,
                color: AppColors.accent,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Get a new suggestion',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.teal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ERROR VIEW ─────────────────────────────────────────────────────────────

class _ErrorView extends StatefulWidget {
  const _ErrorView({this.errorMessage});
  final String? errorMessage;

  @override
  State<_ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<_ErrorView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final curve =
        CurvedAnimation(parent: _entrance, curve: AppAnimations.entranceCurve);

    return Column(
      children: [
        const GradientHeader(
          title: 'AI Suggestion',
          subtitle: 'Something went wrong',
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: curve,
            builder: (context, _) {
              final v = curve.value;
              return Transform.translate(
                offset: Offset(0, 30 * (1 - v)),
                child: Opacity(
                  opacity: v,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppColors.behind.withValues(alpha: 0.06),
                                ),
                              ),
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppColors.behind.withValues(alpha: 0.10),
                                ),
                              ),
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.behindSoft,
                                ),
                                child: const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 28,
                                  color: AppColors.behind,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Couldn\u0027t get a suggestion',
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.errorMessage ??
                                'Please try again in a moment.',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: 200,
                            child: FilledButton.icon(
                              onPressed: () => context
                                  .read<HealthProvider>()
                                  .getSuggestion(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Try again'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── IDLE VIEW ──────────────────────────────────────────────────────────────

class _IdleView extends StatefulWidget {
  const _IdleView();

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final curve = CurvedAnimation(parent: _float, curve: Curves.easeInOut);

    return Column(
      children: [
        const GradientHeader(
          title: 'AI Suggestion',
          subtitle: 'Your personal health advisor',
          trailing: AnimatedSparkleIcon(),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: curve,
                    builder: (context, _) {
                      final v = curve.value;
                      return Transform.translate(
                        offset: Offset(0, -8 * v),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.accent
                                        .withValues(alpha: 0.08 + 0.04 * v),
                                    AppColors.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.accentSoft,
                                    AppColors.surfaceMuted,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 36,
                                color: AppColors.accent.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Ready when you are',
                    style: t.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tap "Get Suggestion" on the Home screen\nto receive personalized health tips.',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    alignment: WrapAlignment.center,
                    children: [
                      _FeatureChip(
                          icon: Icons.restaurant_rounded, label: 'Meals'),
                      _FeatureChip(icon: Icons.bedtime_rounded, label: 'Sleep'),
                      _FeatureChip(
                          icon: Icons.directions_walk_rounded, label: 'Steps'),
                      _FeatureChip(
                          icon: Icons.kitchen_rounded, label: 'Pantry'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── SUGGESTION PARSER ──────────────────────────────────────────────────────

class _SuggestionSection {
  _SuggestionSection({
    this.heading,
    required this.body,
    this.icon,
    this.accentColor,
  });
  final String? heading;
  final String body;
  final IconData? icon;
  final Color? accentColor;
}

IconData _iconForHeading(String heading) {
  final h = heading.toLowerCase();
  if (h.contains('meal') ||
      h.contains('food') ||
      h.contains('eat') ||
      h.contains('nutrition') ||
      h.contains('diet') ||
      h.contains('breakfast') ||
      h.contains('lunch') ||
      h.contains('dinner')) {
    return Icons.restaurant_rounded;
  }
  if (h.contains('sleep') || h.contains('rest') || h.contains('bed')) {
    return Icons.bedtime_rounded;
  }
  if (h.contains('step') ||
      h.contains('walk') ||
      h.contains('exercise') ||
      h.contains('workout') ||
      h.contains('activity') ||
      h.contains('move')) {
    return Icons.directions_walk_rounded;
  }
  if (h.contains('water') || h.contains('hydrat') || h.contains('drink')) {
    return Icons.water_drop_rounded;
  }
  if (h.contains('weight') || h.contains('bmi')) {
    return Icons.monitor_weight_rounded;
  }
  if (h.contains('tip') || h.contains('suggest') || h.contains('recommend')) {
    return Icons.lightbulb_rounded;
  }
  if (h.contains('summary') || h.contains('overview')) {
    return Icons.dashboard_rounded;
  }
  return Icons.auto_awesome_rounded;
}

Color _colorForHeading(String heading) {
  final h = heading.toLowerCase();
  if (h.contains('meal') ||
      h.contains('food') ||
      h.contains('nutrition') ||
      h.contains('diet') ||
      h.contains('breakfast') ||
      h.contains('lunch') ||
      h.contains('dinner')) {
    return AppColors.accent;
  }
  if (h.contains('sleep') || h.contains('rest')) {
    return AppColors.sleep;
  }
  if (h.contains('step') ||
      h.contains('walk') ||
      h.contains('exercise') ||
      h.contains('workout')) {
    return AppColors.onTrack;
  }
  if (h.contains('water') || h.contains('hydrat')) {
    return AppColors.water;
  }
  return AppColors.teal;
}

/// Parse the AI response into meaningful sections.
List<_SuggestionSection> _parseSuggestion(String raw) {
  final lines = raw.split('\n');
  final sections = <_SuggestionSection>[];
  String? currentHeading;
  final buffer = StringBuffer();

  void flushSection() {
    final text = buffer.toString().trim();
    if (text.isEmpty && currentHeading == null) return;
    sections.add(_SuggestionSection(
      heading: currentHeading,
      body: text,
      icon: currentHeading != null ? _iconForHeading(currentHeading!) : null,
      accentColor:
          currentHeading != null ? _colorForHeading(currentHeading!) : null,
    ));
    buffer.clear();
    currentHeading = null;
  }

  final buyRe = RegExp(
      r'^\s*(?:\ud83d\uded2\s*)?(?:\*\*)?buy today(?:\*\*)?\s*:\s*(.*)$',
      caseSensitive: false);

  for (final line in lines) {
    final trimmed = line.trim();

    // "Buy today: X, Y" gets its own shopping-list card.
    final buyMatch = buyRe.firstMatch(trimmed);
    if (buyMatch != null) {
      flushSection();
      final items = buyMatch
          .group(1)!
          .split(RegExp(r'[,;]|\band\b'))
          .map(
              (s) => s.trim().replaceAll(RegExp(r'^[\u2022\-\s]+|[.\s]+$'), ''))
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        sections.add(_SuggestionSection(
          heading: 'Buy today',
          body: items.map((e) => '\ud83d\uded2 $e').join('\n'),
          icon: Icons.shopping_cart_rounded,
          accentColor: AppColors.behind,
        ));
      }
      continue;
    }

    // Detect heading patterns: **Heading**, ## Heading, ### Heading
    final boldMatch = RegExp(r'^\*\*(.+?)\*\*:?$').firstMatch(trimmed);
    final hashMatch = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(trimmed);

    if (boldMatch != null || hashMatch != null) {
      flushSection();
      currentHeading = (boldMatch?.group(1) ?? hashMatch?.group(1))!
          .replaceAll('*', '')
          .trim();
    } else {
      var clean = trimmed;
      if (clean.startsWith('- ') || clean.startsWith('\u2022 ')) {
        clean = '\u2022 ${clean.substring(2)}';
      }
      if (buffer.isNotEmpty && clean.isNotEmpty) buffer.write('\n');
      buffer.write(clean);
    }
  }
  flushSection();

  // If no headings were detected, wrap everything in a single card
  if (sections.isEmpty) {
    sections.add(_SuggestionSection(
      heading: 'Your Personalized Tip',
      body: raw.trim(),
      icon: Icons.auto_awesome_rounded,
      accentColor: AppColors.teal,
    ));
  }

  return sections;
}
