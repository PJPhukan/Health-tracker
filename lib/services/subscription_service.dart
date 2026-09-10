import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat wrapper. Exposes a single `isPremium` flag to the app; the
/// subscription screen drives purchase / restore through it.
///
/// Ships with PLACEHOLDER API keys — until the real ones are set (SETUP.md)
/// [available] stays false: `isPremium` is simply false everywhere, ads keep
/// showing, and the subscription screen shows an "unavailable" state instead of
/// a broken paywall.
class SubscriptionService extends ChangeNotifier {
  static const entitlementId = 'premium';
  static const _iosApiKey = 'appl_placeholder';
  static const _androidApiKey = 'goog_placeholder';

  bool _configured = false;
  bool _available = false;
  bool _isPremium = false;
  bool _busy = false;
  String? _error;
  String? _boundUid;
  Package? _monthly;

  /// The one flag the rest of the app cares about.
  bool get isPremium => _isPremium;

  /// True when RevenueCat is configured and its offerings loaded.
  bool get available => _available;

  bool get busy => _busy;
  String? get error => _error;

  Package? get monthlyPackage => _monthly;
  String? get monthlyPriceString => _monthly?.storeProduct.priceString;

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get usingPlaceholderKeys =>
      _iosApiKey.endsWith('_placeholder') ||
      _androidApiKey.endsWith('_placeholder');

  Future<void> init() async {
    if (_configured || !_supported) return;
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      final key = Platform.isIOS ? _iosApiKey : _androidApiKey;
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_applyInfo);
      await refresh();
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat configure failed: $e');
    }
  }

  /// Tie purchases to the signed-in account so entitlements follow the user
  /// across devices. Called from the provider graph on auth changes.
  Future<void> identify(String? uid) async {
    if (!_configured) return;
    final target = (uid == null || uid.isEmpty || uid == 'local') ? null : uid;
    if (target == _boundUid) return;
    _boundUid = target;
    try {
      if (target == null) {
        await Purchases.logOut();
      } else {
        await Purchases.logIn(target);
      }
      await refresh();
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat identify failed: $e');
    }
  }

  /// Re-checks entitlement + offerings. Safe to call on login and app resume.
  Future<void> refresh() async {
    if (!_configured) return;
    try {
      _applyInfo(await Purchases.getCustomerInfo());
      final offerings = await Purchases.getOfferings();
      _monthly = offerings.current?.monthly;
      _available = true;
      _error = null;
    } catch (e) {
      _available = false;
      if (kDebugMode) debugPrint('RevenueCat refresh failed: $e');
    }
    notifyListeners();
  }

  void _applyInfo(CustomerInfo info) {
    final premium = info.entitlements.active.containsKey(entitlementId);
    if (premium != _isPremium) {
      _isPremium = premium;
      notifyListeners();
    }
  }

  Future<bool> purchaseMonthly() async {
    final pkg = _monthly;
    if (pkg == null) {
      _error = 'No subscription is available right now.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      _applyInfo(result.customerInfo);
      return _isPremium;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _error = _messageFor(code);
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('purchase failed: $e');
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> restore() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _applyInfo(await Purchases.restorePurchases());
      if (!_isPremium) _error = 'No previous purchase found on this account.';
      return _isPremium;
    } catch (e) {
      if (kDebugMode) debugPrint('restore failed: $e');
      _error = "Couldn't restore purchases. Try again.";
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _messageFor(PurchasesErrorCode code) => switch (code) {
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are not allowed on this device.',
        PurchasesErrorCode.paymentPendingError =>
          'Your payment is pending approval.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own this — try "Restore purchases".',
        PurchasesErrorCode.networkError =>
          'No connection. Check your network and try again.',
        PurchasesErrorCode.storeProblemError =>
          'The app store had a problem. Try again in a moment.',
        _ => 'The purchase could not be completed.',
      };
}
