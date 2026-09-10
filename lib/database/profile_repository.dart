import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/user_profile.dart';
import '../services/firebase_bootstrap.dart';
import 'database_helper.dart';

/// Where a loaded profile came from, so the UI can show a sync hint.
enum ProfileSource { firestore, localCache, none }

class ProfileLoad {
  const ProfileLoad(this.profile, this.source, {this.offline = false});
  final UserProfile? profile;
  final ProfileSource source;

  /// True when Firestore was expected but unreachable — local data was used.
  final bool offline;
}

/// Reads/writes the user profile + goals.
///
/// Source of truth is Firestore `users/{uid}` (with `goals` as a nested map).
/// Every read and write is mirrored into the local `user_profiles` table so the
/// app keeps working offline and in local-only mode.
class ProfileRepository {
  ProfileRepository({DatabaseHelper? helper, FirebaseFirestore? firestore})
      : _helper = helper ?? DatabaseHelper.instance,
        _injectedFs = firestore;

  final DatabaseHelper _helper;
  final FirebaseFirestore? _injectedFs;

  bool get _cloudEnabled => FirebaseBootstrap.isReady;

  FirebaseFirestore get _fs => _injectedFs ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _fs.collection('users').doc(uid);

  Future<ProfileLoad> load(String profileId) async {
    if (_cloudEnabled && profileId != UserProfileIds.local) {
      try {
        final snap = await _doc(profileId).get(
          const GetOptions(source: Source.serverAndCache),
        );
        final data = snap.data();
        if (data != null) {
          final profile = UserProfile.fromMap(_normalise(data));
          await _saveLocal(profileId, profile);
          return ProfileLoad(profile, ProfileSource.firestore,
              offline: snap.metadata.isFromCache);
        }
        // No cloud doc yet — fall through to any local draft.
      } catch (e) {
        if (kDebugMode) debugPrint('Firestore profile load failed: $e');
        final local = await _loadLocal(profileId);
        return ProfileLoad(local, ProfileSource.localCache, offline: true);
      }
    }

    final local = await _loadLocal(profileId);
    return ProfileLoad(
      local,
      local == null ? ProfileSource.none : ProfileSource.localCache,
    );
  }

  /// Persists locally always; pushes to Firestore when possible. Returns true if
  /// the cloud write also succeeded (false = saved locally, will not auto-sync).
  Future<bool> save(UserProfile profile) async {
    await _saveLocal(profile.uid, profile);

    if (!_cloudEnabled || profile.uid == UserProfileIds.local) return false;
    try {
      await _doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore profile save failed: $e');
      return false;
    }
  }

  /// Writes just the goals back (used by the "edit goals" flow).
  Future<bool> saveGoals(UserProfile current, HealthGoals goals) =>
      save(current.copyWith(goals: goals));

  // ---- local mirror ----

  Future<UserProfile?> _loadLocal(String profileId) async {
    final db = await _helper.database;
    final rows = await db.query('user_profiles',
        where: 'profileId = ?', whereArgs: [profileId], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return UserProfile.fromJson(rows.first['json'] as String);
    } catch (e) {
      if (kDebugMode) debugPrint('Corrupt local profile: $e');
      return null;
    }
  }

  Future<void> _saveLocal(String profileId, UserProfile profile) async {
    final db = await _helper.database;
    await db.insert(
      'user_profiles',
      {
        'profileId': profileId,
        'json': profile.toJson(),
        'updatedAt': profile.updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Firestore hands back `Map<String, dynamic>`; the models want
  /// `Map<String, Object?>` and nested maps need the same treatment.
  Map<String, Object?> _normalise(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(
          k,
          v is Map ? Map<String, Object?>.from(v) : v as Object?,
        ));
  }
}

class UserProfileIds {
  static const local = 'local';
}
