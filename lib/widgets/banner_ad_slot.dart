import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../theme/app_theme.dart';

/// A self-contained banner ad. Renders nothing (zero height) unless AdMob is up,
/// the user is on the free tier, and an ad actually loads — a failed load is
/// silent. Owns its own [BannerAd] and disposes it correctly.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _adsEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = context.watch<AdService>().adsEnabled;
    if (enabled != _adsEnabled) {
      _adsEnabled = enabled;
      if (enabled) {
        _load();
      } else {
        _dispose();
      }
    }
  }

  void _load() {
    if (_ad != null) return;
    final ads = context.read<AdService>();
    final banner = BannerAd(
      adUnitId: ads.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = banner;
    banner.load();
  }

  void _dispose() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adsEnabled || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      alignment: Alignment.center,
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
