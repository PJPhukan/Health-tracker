import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_bootstrap.dart';

/// A user-presentable auth error. Every Firebase/Google exception is mapped to
/// one of these so the UI never shows a raw `[firebase_auth/...]` string.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Signals the user backed out of the Google sheet — not an error worth showing.
class AuthCancelled implements Exception {}

/// Wraps FirebaseAuth + Google Sign-In v7.
///
/// Every method first checks [isAvailable]; with no Firebase config the app
/// runs signed-out in local-only mode rather than throwing on startup.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _injectedAuth = auth;

  final FirebaseAuth? _injectedAuth;
  bool _googleInitialised = false;

  bool get isAvailable => FirebaseBootstrap.isReady;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  /// Emits on sign-in/sign-out. A single `null` when Firebase is unavailable,
  /// so the gate can settle into local-only mode instead of hanging.
  Stream<User?> authStateChanges() {
    if (!isAvailable) return Stream<User?>.value(null);
    return _auth.authStateChanges();
  }

  User? get currentUser => isAvailable ? _auth.currentUser : null;

  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          ));

  Future<void> signUpWithEmail(String email, String password) =>
      _guard(() => _auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          ));

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  /// google_sign_in 7.x: `initialize()` once, then `authenticate()`, then hand
  /// the resulting idToken to Firebase.
  Future<void> signInWithGoogle() async {
    _requireFirebase();
    final google = GoogleSignIn.instance;
    try {
      if (!_googleInitialised) {
        await google.initialize();
        _googleInitialised = true;
      }
      if (!google.supportsAuthenticate()) {
        throw AuthFailure(
            'Google Sign-In is not supported on this platform. Use email and '
            'password instead.');
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw AuthFailure('Google did not return an ID token. Try again.');
      }
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw AuthCancelled();
      }
      if (kDebugMode) debugPrint('Google sign-in failed: $e');
      throw AuthFailure("Couldn't sign in with Google. Try again.");
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    if (_googleInitialised) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // A failed Google sign-out must not block the Firebase sign-out.
      }
    }
    await _auth.signOut();
  }

  void _requireFirebase() {
    if (!isAvailable) {
      throw AuthFailure(FirebaseBootstrap.error ??
          'Accounts are unavailable — Firebase is not configured.');
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    _requireFirebase();
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } catch (e) {
      if (kDebugMode) debugPrint('Auth call failed: $e');
      throw AuthFailure('Something went wrong. Please try again.');
    }
  }

  String _messageFor(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address doesn’t look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' =>
          'That email is already registered. Try signing in.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'operation-not-allowed' =>
          'This sign-in method isn’t enabled in Firebase yet.',
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        'too-many-requests' => 'Too many attempts. Try again in a moment.',
        'account-exists-with-different-credential' =>
          'This email is already registered with a different sign-in method.',
        _ => 'Something went wrong. Please try again.',
      };
}
