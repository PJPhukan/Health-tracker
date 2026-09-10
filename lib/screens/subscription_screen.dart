import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Future<void> _subscribe(BuildContext context) async {
    final sub = context.read<SubscriptionService>();
    final ok = await sub.purchaseMonthly();
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You’re Premium — ads are off. Thanks!')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _restore(BuildContext context) async {
    final sub = context.read<SubscriptionService>();
    final ok = await sub.restore();
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium restored')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();
    final t = Theme.of(context).textTheme;
    final price = sub.monthlyPriceString;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Stock Plate Premium',
            subtitle: 'Support the app, lose the ads',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              children: [
                if (sub.isPremium) ...[
                  _ActiveCard(),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (sub.error != null) ...[
                  ErrorBanner(message: sub.error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _PlanCard(
                        title: 'Free',
                        price: '\$0',
                        highlighted: !sub.isPremium,
                        perks: const [
                          _Perk('Unlimited AI suggestions', true),
                          _Perk('All tracking & sync', true),
                          _Perk('Shows ads', false),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _PlanCard(
                        title: 'Premium',
                        price: price == null ? '—' : '$price/mo',
                        highlighted: sub.isPremium,
                        perks: const [
                          _Perk('Unlimited AI suggestions', true),
                          _Perk('All tracking & sync', true),
                          _Perk('No ads, anywhere', true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!sub.available)
                  _UnavailableNote(placeholder: sub.usingPlaceholderKeys)
                else if (!sub.isPremium) ...[
                  BusyButton(
                    label: price == null
                        ? 'Subscribe'
                        : 'Subscribe — $price/month',
                    busy: sub.busy,
                    onPressed: () => _subscribe(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: sub.busy ? null : () => _restore(context),
                    child: const Text('Restore purchases'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: sub.busy ? null : () => _restore(context),
                    child: const Text('Restore purchases'),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Subscriptions renew monthly until cancelled. Manage or cancel '
                  'anytime in your ${_storeName()} account.',
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _storeName() {
    return 'App Store / Play Store';
  }
}

class _ActiveCard extends StatelessWidget {
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
            icon: Icons.workspace_premium_rounded,
            color: AppColors.onTrack,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Premium is active — no ads. Thank you!',
                style: t.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.perks,
    required this.highlighted,
  });

  final String title;
  final String price;
  final List<_Perk> perks;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.teal : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: t.titleMedium?.copyWith(
                  color: highlighted ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(price,
              style: t.titleLarge?.copyWith(
                  color: highlighted ? Colors.white : AppColors.teal,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          for (final perk in perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    perk.good
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: highlighted
                        ? Colors.white
                        : (perk.good
                            ? AppColors.onTrack
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      perk.label,
                      style: t.bodyMedium?.copyWith(
                        color: highlighted
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Perk {
  const _Perk(this.label, this.good);
  final String label;
  final bool good;
}

class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote({required this.placeholder});
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              placeholder
                  ? 'Subscriptions aren’t wired up in this build yet. '
                      'Add the RevenueCat API keys to enable Premium.'
                  : 'Subscriptions are temporarily unavailable. Please try '
                      'again later.',
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
