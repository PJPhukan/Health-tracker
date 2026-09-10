// Firebase configuration.
//
// ─── REPLACE THIS FILE ──────────────────────────────────────────────────────
// These are PLACEHOLDER values so the project compiles and runs before a
// Firebase project exists. While the sentinel below is present the app runs in
// "local-only" mode: no auth, no cloud sync, everything else works.
//
// To wire up a real project:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// which overwrites this file with your real values (and drops
// android/app/google-services.json + ios/Runner/GoogleService-Info.plist).
// ────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Marker that identifies the un-configured placeholder values below.
const _placeholder = 'REPLACE_ME';

class DefaultFirebaseOptions {
  /// False while this file still holds placeholder values, which is how the
  /// app decides to run without Firebase instead of crashing on startup.
  static bool get isConfigured => !_android.apiKey.contains(_placeholder);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _ios;
      default:
        return _web;
    }
  }

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: '${_placeholder}_ANDROID_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'stock-plate',
    storageBucket: 'stock-plate.firebasestorage.app',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: '${_placeholder}_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'stock-plate',
    storageBucket: 'stock-plate.firebasestorage.app',
    iosBundleId: 'com.example.healthTracker',
  );

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: '${_placeholder}_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'stock-plate',
    authDomain: 'stock-plate.firebaseapp.com',
    storageBucket: 'stock-plate.firebasestorage.app',
  );
}
