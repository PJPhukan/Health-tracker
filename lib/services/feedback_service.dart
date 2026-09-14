import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/health_repository.dart';
import '../models/suggestion_feedback.dart';
import 'firebase_bootstrap.dart';

class FeedbackService {
  FeedbackService({
    HealthRepository? repo,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _repo = repo,
        _firestore = firestore,
        _auth = auth;

  HealthRepository? _repo;
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  void bindRepository(HealthRepository repo) {
    _repo = repo;
  }

  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _af => _auth ?? FirebaseAuth.instance;

  /// Records feedback locally in SQLite and pushes to Firestore if authenticated.
  Future<void> recordFeedback({
    required String suggestionId,
    required String rating, // 'positive' or 'negative'
    String? reason,
    String? comment,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final feedback = SuggestionFeedback(
      suggestionId: suggestionId,
      rating: rating,
      reason: reason?.trim().isEmpty == true ? null : reason?.trim(),
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      timestamp: timestamp,
    );

    // 1. Insert into local SQLite
    if (_repo != null) {
      await _repo!.insertSuggestionFeedback(feedback);
    }

    // 2. Mirror directly to Firestore users/{uid}/suggestion_feedback if signed in
    if (FirebaseBootstrap.isReady) {
      try {
        final uid = _af.currentUser?.uid;
        if (uid != null && uid.isNotEmpty && uid != 'local') {
          await _fs
              .collection('users')
              .doc(uid)
              .collection('suggestion_feedback')
              .add(feedback.toMap());
        }
      } catch (e) {
        debugPrint('FeedbackService: Firestore push failed (will sync via SyncService): $e');
      }
    }
  }

  /// Checks if the user gave negative feedback with reason "Missing ingredients" > 2 times.
  Future<bool> hasRepeatedMissingIngredientsWarning() async {
    if (_repo == null) return false;
    final count = await _repo!.getNegativeFeedbackCountForReason('Missing ingredients');
    return count > 2;
  }
}
