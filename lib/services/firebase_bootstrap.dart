import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Starts Firebase without letting a missing/broken config take the app down.
///
/// v1 shipped with no backend at all, so v2 must still run for someone who
/// hasn't created a Firebase project yet (and for the debug APK we build in
/// CI). When [isReady] is false the app falls back to **local-only mode**:
/// there is no sign-in, and the profile/goals live purely in SQLite.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;
  static String? _error;

  /// True once Firebase initialised successfully — gates every cloud feature.
  static bool get isReady => _ready;

  /// Why Firebase is unavailable, for the Settings screen to surface.
  static String? get error => _error;

  static Future<void> init() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      _error = 'Firebase is not configured yet — running in local-only mode. '
          'Run `flutterfire configure` to enable accounts and cloud sync.';
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
    } catch (e) {
      _error = 'Could not start Firebase: $e';
      if (kDebugMode) debugPrint('Firebase init failed: $e');
    }
  }
}
