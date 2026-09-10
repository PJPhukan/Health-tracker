import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/firebase_bootstrap.dart';
import 'database_helper.dart';

/// Two-way sync between local SQLite and Firestore `users/{uid}/<collection>`.
///
/// Design (v3):
///  * every write in [HealthRepository] lands in SQLite first with
///    `pendingSync = 1`; reads never touch the network.
///  * [pushPending] flushes the pending rows (and tombstones) to Firestore.
///  * [pullRemote] merges the cloud copy back down, last-write-wins on
///    `syncUpdatedAt`, and drops local rows that were deleted elsewhere.
///  * [runInitialMigration] is the one-time "lift existing local data up"
///    step, guarded by a per-uid SharedPreferences flag.
///
/// Everything is best-effort: a failed Firestore call just leaves the row
/// `pendingSync = 1` to be retried on the next [syncNow].
class SyncService {
  SyncService({
    DatabaseHelper? helper,
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
  })  : _helper = helper ?? DatabaseHelper.instance,
        _injectedFs = firestore,
        _prefs = prefs;

  final DatabaseHelper _helper;
  final FirebaseFirestore? _injectedFs;
  SharedPreferences? _prefs;

  static const _uuid = Uuid();

  /// Tables whose id is `d_<date>` (one row per day) so a same-day replace maps
  /// to the same Firestore document.
  static const _perDayTables = {
    'sleep_entries',
    'weight_entries',
    'steps_entries',
  };

  String? _uid;
  bool _syncing = false;

  FirebaseFirestore get _fs => _injectedFs ?? FirebaseFirestore.instance;

  bool get enabled =>
      FirebaseBootstrap.isReady && _uid != null && _uid != 'local';

  /// Point the service at the signed-in user (or null on sign-out / local mode).
  void bind(String? uid) {
    _uid = (uid == null || uid.isEmpty) ? null : uid;
  }

  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  CollectionReference<Map<String, dynamic>> _col(String sqliteTable) => _fs
      .collection('users')
      .doc(_uid)
      .collection(DatabaseHelper.syncedCollections[sqliteTable]!);

  /// Generate a stable id for a new row in [table].
  String newSyncId(String table, {String? date}) =>
      _perDayTables.contains(table) && date != null
          ? 'd_$date'
          : _uuid.v4();

  bool isPerDay(String table) => _perDayTables.contains(table);

  // ── the public entry point ────────────────────────────────────────────────

  /// Full reconcile: one-time migration (if pending) → pull → push.
  /// Safe to call on login and on every app resume.
  Future<void> syncNow() async {
    if (!enabled || _syncing) return;
    _syncing = true;
    try {
      await runInitialMigration();
      await pullRemote();
      await pushPending();
    } catch (e) {
      if (kDebugMode) debugPrint('syncNow failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Fire-and-forget flush used right after a local write.
  void pushSoon() {
    if (!enabled) return;
    Future(() async {
      try {
        await pushPending();
      } catch (e) {
        if (kDebugMode) debugPrint('pushSoon failed: $e');
      }
    });
  }

  // ── one-time migration ────────────────────────────────────────────────────

  String _migrationFlag(String uid) => 'v3_sync_migrated_$uid';

  Future<void> runInitialMigration() async {
    if (!enabled) return;
    final prefs = await _sp;
    if (prefs.getBool(_migrationFlag(_uid!)) == true) return;

    final db = await _helper.database;
    final now = DateTime.now().toIso8601String();
    for (final table in DatabaseHelper.syncedCollections.keys) {
      final rows = await db.query(table,
          columns: ['id', 'date'], where: 'syncId IS NULL');
      for (final row in rows) {
        final id = row['id'] as int;
        final date = row['date'] as String?;
        await db.update(
          table,
          {
            'syncId': newSyncId(table, date: date),
            'pendingSync': 1,
            'syncUpdatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    await pushPending();
    await prefs.setBool(_migrationFlag(_uid!), true);
  }

  // ── push ──────────────────────────────────────────────────────────────────

  static const _sqliteOnlyKeys = {'id', 'pendingSync', 'syncDeleted'};

  Map<String, dynamic> _toDoc(Map<String, Object?> row) {
    final doc = <String, dynamic>{};
    for (final entry in row.entries) {
      if (_sqliteOnlyKeys.contains(entry.key)) continue;
      if (entry.value != null) doc[entry.key] = entry.value;
    }
    return doc;
  }

  Future<void> pushPending() async {
    if (!enabled) return;
    final db = await _helper.database;

    for (final table in DatabaseHelper.syncedCollections.keys) {
      final pending = await db.query(table, where: 'pendingSync = 1');
      for (final row in pending) {
        final id = row['id'] as int;
        final syncId = row['syncId'] as String?;
        if (syncId == null) continue;
        try {
          if ((row['syncDeleted'] as int? ?? 0) == 1) {
            await _col(table).doc(syncId).delete();
            await db.delete(table, where: 'id = ?', whereArgs: [id]);
          } else {
            await _col(table)
                .doc(syncId)
                .set(_toDoc(row), SetOptions(merge: true));
            await db.update(table, {'pendingSync': 0},
                where: 'id = ?', whereArgs: [id]);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('push $table/$syncId failed: $e');
          // leave pendingSync = 1 for the next attempt
        }
      }
    }
  }

  // ── pull ──────────────────────────────────────────────────────────────────

  Future<void> pullRemote() async {
    if (!enabled) return;
    final db = await _helper.database;

    for (final table in DatabaseHelper.syncedCollections.keys) {
      final QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _col(table).get();
      } catch (e) {
        if (kDebugMode) debugPrint('pull $table failed: $e');
        continue; // never touch local data when the fetch didn't succeed
      }

      final remoteIds = <String>{};
      for (final doc in snap.docs) {
        remoteIds.add(doc.id);
        final data = doc.data();
        final remoteUpdated = (data['syncUpdatedAt'] as String?) ?? '';

        final existing = await db.query(table,
            columns: ['id', 'syncUpdatedAt', 'pendingSync'],
            where: 'syncId = ?',
            whereArgs: [doc.id],
            limit: 1);

        final localRow = existing.isEmpty ? null : existing.first;
        final localPending = (localRow?['pendingSync'] as int? ?? 0) == 1;
        final localUpdated = (localRow?['syncUpdatedAt'] as String?) ?? '';

        // Local unsynced edits win until they've been pushed.
        if (localPending) continue;
        if (localRow != null && localUpdated.compareTo(remoteUpdated) >= 0) {
          continue;
        }

        final values = _rowFromRemote(table, doc.id, data);
        if (localRow == null) {
          await db.insert(table, values,
              conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await db.update(table, values,
              where: 'id = ?', whereArgs: [localRow['id']]);
        }
      }

      // Rows that were synced before but are gone from the cloud were deleted
      // on another device (or belong to a different account on this device).
      final synced = await db.query(table,
          columns: ['id', 'syncId'],
          where: 'pendingSync = 0 AND syncDeleted = 0 AND syncId IS NOT NULL');
      for (final row in synced) {
        if (!remoteIds.contains(row['syncId'])) {
          await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    }
  }

  /// Firestore doc -> SQLite row values (domain columns + sync bookkeeping).
  Map<String, Object?> _rowFromRemote(
      String table, String docId, Map<String, dynamic> data) {
    final values = <String, Object?>{
      'syncId': docId,
      'pendingSync': 0,
      'syncDeleted': 0,
      'syncUpdatedAt': data['syncUpdatedAt'] ?? DateTime.now().toIso8601String(),
    };
    for (final entry in data.entries) {
      if (entry.key == 'syncUpdatedAt' || entry.key == 'id') continue;
      final v = entry.value;
      // Normalise Firestore numeric/bool types back to what SQLite stores.
      if (v is bool) {
        values[entry.key] = v ? 1 : 0;
      } else if (v is Timestamp) {
        values[entry.key] = v.toDate().toIso8601String();
      } else {
        values[entry.key] = v;
      }
    }
    return values;
  }
}
