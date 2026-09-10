import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob wiring for the free tier.
///
/// Free users see a banner at the bottom of Home and the Suggestion screen;
/// premium users see nothing. [SubscriptionService] pushes the premium flag in
/// (stage 3) so ads vanish the instant a purchase completes — no restart.
///
/// This object only holds *state*; each screen builds its own [BannerAd] via a
/// `BannerAdSlot` widget, because one `BannerAd` instance can't back two
/// `AdWidget`s at once.
class AdService extends ChangeNotifier {
  bool _initialized = false;
  bool _premium = false;

  /// True once AdMob is up and the user is on the free tier on a platform that
  /// serves ads. Screens watch this to decide whether to mount a banner.
  bool get adsEnabled => _initialized && !_premium && _supportedPlatform;

  bool get _supportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Google's sample banner unit — replace with the real unit before release
  /// (see SETUP.md).
  String get bannerUnitId => 'ca-app-pub-3940256099942544/6300978111';

  Future<void> init() async {
    if (_initialized || !_supportedPlatform) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('AdMob init failed: $e');
    }
  }

  /// Called by the subscription layer. Toggling premium on tears every banner
  /// down (via [adsEnabled] flipping false); toggling off brings them back.
  void setPremium(bool premium) {
    if (premium == _premium) return;
    _premium = premium;
    notifyListeners();
  }
}
