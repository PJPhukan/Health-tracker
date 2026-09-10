// File generated for the `stock-plate` Firebase project.
//
// Regenerate with:  flutterfire configure --project=stock-plate
//
// The [DefaultFirebaseOptions.isConfigured] getter is a small local addition
// (see services/firebase_bootstrap.dart): it stays false only if this file is
// reverted to placeholder values, so the app can fall back to local-only mode
// instead of crashing.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  /// False only while this file holds placeholder values — lets the app run
  /// without Firebase rather than crash on startup.
  static bool get isConfigured => !web.apiKey.contains('REPLACE_ME');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDT6IKtU4q2bGyvNRrIxZ15QEFT9uvMel4',
    appId: '1:916437613429:web:f55900634eb55c094ef13c',
    messagingSenderId: '916437613429',
    projectId: 'stock-plate',
    authDomain: 'stock-plate.firebaseapp.com',
    storageBucket: 'stock-plate.firebasestorage.app',
    measurementId: 'G-PCXMR1YJ99',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDIEaAWiZuf5mblXJXJKdCF9Wmes5emew4',
    appId: '1:916437613429:android:6eb8fcb9db3fe87a4ef13c',
    messagingSenderId: '916437613429',
    projectId: 'stock-plate',
    storageBucket: 'stock-plate.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDMAupottV0yIIKowv5e1p8ihwK1-UPXEc',
    appId: '1:916437613429:ios:aa096f0ba71604644ef13c',
    messagingSenderId: '916437613429',
    projectId: 'stock-plate',
    storageBucket: 'stock-plate.firebasestorage.app',
    iosBundleId: 'com.example.healthTracker',
  );
}
