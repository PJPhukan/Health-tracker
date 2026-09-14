import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._() {
    _init();
  }

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOffline = false;
  bool _bannerDismissed = false;

  bool get isOffline => _isOffline;
  bool get shouldShowBanner => _isOffline && !_bannerDismissed;

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (_) {
      // Default to online if check fails
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (_isOffline != offline) {
      _isOffline = offline;
      if (!_isOffline) {
        // Automatically reset dismissal state when coming back online
        _bannerDismissed = false;
      }
      notifyListeners();
    }
  }

  void dismissBanner() {
    _bannerDismissed = true;
    notifyListeners();
  }

  @visibleForTesting
  void setOfflineForTesting(bool offline) {
    _isOffline = offline;
    _bannerDismissed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
