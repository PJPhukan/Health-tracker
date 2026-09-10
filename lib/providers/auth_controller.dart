import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/firebase_bootstrap.dart';

/// Where the app is in the auth lifecycle.
enum AuthStage {
  /// Still resolving the cached session.
  checking,

  /// Firebase isn't configured — no accounts, everything stays on-device.
  localOnly,

  /// Firebase is live but nobody is signed in.
  signedOut,

  /// Signed in.
  signedIn,
}

/// Owns auth state for the widget tree.
///
/// Named `AuthController` rather than `AuthProvider` on purpose —
/// `firebase_auth` already exports a class called `AuthProvider`.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
      : _service = service ?? AuthService() {
    _listen();
  }

  final AuthService _service;
  StreamSubscription<User?>? _sub;

  AuthStage _stage = AuthStage.checking;
  AuthStage get stage => _stage;

  User? _user;
  User? get user => _user;

  /// Stable id for the profile store: the Firebase uid, or `local` off-grid.
  String get profileId => _user?.uid ?? localProfileId;
  static const localProfileId = 'local';

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool get firebaseAvailable => _service.isAvailable;
  String? get firebaseError => FirebaseBootstrap.error;

  void _listen() {
    if (!_service.isAvailable) {
      _stage = AuthStage.localOnly;
      return;
    }
    _sub = _service.authStateChanges().listen((user) {
      _user = user;
      _stage = user == null ? AuthStage.signedOut : AuthStage.signedIn;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _service.signInWithEmail(email, password));

  Future<bool> signUp(String email, String password) =>
      _run(() => _service.signUpWithEmail(email, password));

  Future<bool> signInWithGoogle() => _run(_service.signInWithGoogle);

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _service.sendPasswordReset(email));

  Future<void> signOut() async {
    await _service.signOut();
  }

  /// Runs an auth call with busy/error bookkeeping. Returns true on success.
  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthCancelled {
      return false; // User dismissed the sheet — say nothing.
    } on AuthFailure catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Auth action failed: $e');
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
