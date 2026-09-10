import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database_helper.dart';
import 'sync_service.dart';

/// Single source of truth over all health tables.
///
/// v3: every table also mirrors to Firestore. Callers are unchanged — the dual
/// write (SQLite first, then a best-effort Firestore push) and the sync
/// bookkeeping columns are handled entirely here and in [SyncService]. Reads
/// still come straight from SQLite and transparently skip soft-deleted rows.
class HealthRepository {
  HealthRepository({DatabaseHelper? helper, SyncService? sync})
      : _helper = helper ?? DatabaseHelper.instance,
        _sync = sync;

  final DatabaseHelper _helper;
  final SyncService? _sync;

  Future<Database> get _db => _helper.database;

  bool get _syncEnabled => _sync?.enabled ?? false;
  String _now() => DateTime.now().toIso8601String();

  String _since(int days) {
    final d = DateTime.now().subtract(Duration(days: days - 1));
    return dateKey(DateTime(d.year, d.month, d.day));
  }

  /// `<original where>` AND not soft-deleted.
  String _live([String? where]) =>
      where == null ? 'syncDeleted = 0' : '($where) AND syncDeleted = 0';

  // ── generic sync-aware writes ─────────────────────────────────────────────

  Future<int> _insert(String table, Map<String, Object?> map,
      {String? date}) async {
    final db = await _db;
    final row = {
      ...map,
      'syncId': _sync?.newSyncId(table, date: date) ?? _fallbackId(table, date),
      'pendingSync': 1,
      'syncDeleted': 0,
      'syncUpdatedAt': _now(),
    };
    final id = await db.insert(table, row);
    _sync?.pushSoon();
    return id;
  }

  Future<int> _update(String table, Map<String, Object?> map, int id) async {
    final db = await _db;
    final row = {...map}
      ..remove('id')
      ..['pendingSync'] = 1
      ..['syncUpdatedAt'] = _now();
    final n = await db.update(table, row, where: 'id = ?', whereArgs: [id]);
    _sync?.pushSoon();
    return n;
  }

  Future<int> _delete(String table, int id) async {
    final db = await _db;
    final int n;
    if (_syncEnabled) {
      n = await db.update(
        table,
        {'syncDeleted': 1, 'pendingSync': 1, 'syncUpdatedAt': _now()},
        where: 'id = ?',
        whereArgs: [id],
      );
      _sync?.pushSoon();
    } else {
      n = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    return n;
  }

  /// One-row-per-day replace: same [date] maps to the same `syncId`, so a
  /// replace is a plain overwrite — no tombstone needed.
  Future<int> _replaceForDay(
      String table, String date, Map<String, Object?> map) async {
    final db = await _db;
    await db.delete(table, where: 'date = ?', whereArgs: [date]);
    return _insert(table, map, date: date);
  }

  String _fallbackId(String table, String? date) =>
      (const {'sleep_entries', 'weight_entries', 'steps_entries'}
                  .contains(table) &&
              date != null)
          ? 'd_$date'
          : 'local-${DateTime.now().microsecondsSinceEpoch}';

  // ── Meals ────────────────────────────────────────────────────────────────

  Future<int> insertMeal(MealEntry e) => _insert('meal_entries', e.toMap());

  Future<int> deleteMeal(int id) => _delete('meal_entries', id);

  Future<int> updateMeal(MealEntry entry) =>
      _update('meal_entries', entry.toMap(), entry.id!);

  Future<List<MealEntry>> getTodayMeals() =>
      getMealsForDate(dateKey(DateTime.now()));

  Future<List<MealEntry>> getMealsForDate(String date) async {
    final rows = await (await _db).query('meal_entries',
        where: _live('date = ?'),
        whereArgs: [date],
        orderBy: 'timestamp DESC');
    return rows.map(MealEntry.fromMap).toList();
  }

  // ── Workouts ─────────────────────────────────────────────────────────────

  Future<int> insertWorkout(WorkoutEntry e) =>
      _insert('workout_entries', e.toMap());

  Future<int> deleteWorkout(int id) => _delete('workout_entries', id);

  Future<int> updateWorkout(WorkoutEntry entry) =>
      _update('workout_entries', entry.toMap(), entry.id!);

  Future<List<WorkoutEntry>> getTodayWorkouts() =>
      getWorkoutsForDate(dateKey(DateTime.now()));

  Future<List<WorkoutEntry>> getWorkoutsForDate(String date) async {
    final rows = await (await _db).query('workout_entries',
        where: _live('date = ?'),
        whereArgs: [date],
        orderBy: 'timestamp DESC');
    return rows.map(WorkoutEntry.fromMap).toList();
  }

  // ── Sleep ────────────────────────────────────────────────────────────────

  Future<int> insertSleep(SleepEntry e) =>
      _replaceForDay('sleep_entries', e.date, e.toMap());

  Future<SleepEntry?> getSleepForDate(String date) async {
    final rows = await (await _db).query('sleep_entries',
        where: _live('date = ?'), whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : SleepEntry.fromMap(rows.first);
  }

  Future<SleepEntry?> getTodaySleep() =>
      getSleepForDate(dateKey(DateTime.now()));

  Future<int> updateSleep(SleepEntry entry) =>
      _update('sleep_entries', entry.toMap(), entry.id!);

  Future<int> deleteSleep(int id) => _delete('sleep_entries', id);

  // ── Weight ───────────────────────────────────────────────────────────────

  Future<int> insertWeight(WeightEntry e) =>
      _replaceForDay('weight_entries', e.date, e.toMap());

  Future<WeightEntry?> getWeightForDate(String date) async {
    final rows = await (await _db).query('weight_entries',
        where: _live('date = ?'), whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : WeightEntry.fromMap(rows.first);
  }

  Future<WeightEntry?> getTodayWeight() =>
      getWeightForDate(dateKey(DateTime.now()));

  Future<int> updateWeight(WeightEntry entry) =>
      _update('weight_entries', entry.toMap(), entry.id!);

  Future<int> deleteWeight(int id) => _delete('weight_entries', id);

  Future<List<WeightEntry>> getRecentWeight({int days = 30}) async {
    final rows = await (await _db).query('weight_entries',
        where: _live('date >= ?'),
        whereArgs: [_since(days)],
        orderBy: 'date ASC');
    return rows.map(WeightEntry.fromMap).toList();
  }

  // ── Steps ────────────────────────────────────────────────────────────────

  Future<int> insertSteps(StepsEntry e) =>
      _replaceForDay('steps_entries', e.date, e.toMap());

  Future<StepsEntry?> getStepsForDate(String date) async {
    final rows = await (await _db).query('steps_entries',
        where: _live('date = ?'), whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : StepsEntry.fromMap(rows.first);
  }

  Future<StepsEntry?> getTodaySteps() =>
      getStepsForDate(dateKey(DateTime.now()));

  Future<int> updateSteps(StepsEntry entry) =>
      _update('steps_entries', entry.toMap(), entry.id!);

  Future<int> deleteSteps(int id) => _delete('steps_entries', id);

  Future<List<StepsEntry>> getRecentSteps({int days = 7}) async {
    final rows = await (await _db).query('steps_entries',
        where: _live('date >= ?'),
        whereArgs: [_since(days)],
        orderBy: 'date ASC');
    return rows.map(StepsEntry.fromMap).toList();
  }

  // ── Pantry ───────────────────────────────────────────────────────────────

  Future<int> insertPantryItem(PantryItem e) =>
      _insert('pantry_items', e.toMap());

  Future<int> updatePantryItem(PantryItem e) =>
      _update('pantry_items', e.toMap(), e.id!);

  Future<int> deletePantryItem(int id) => _delete('pantry_items', id);

  Future<List<PantryItem>> getAllPantryItems() async {
    final rows = await (await _db).query('pantry_items',
        where: _live(), orderBy: 'isLow DESC, itemName COLLATE NOCASE ASC');
    return rows.map(PantryItem.fromMap).toList();
  }

  // ── Meal favorites ───────────────────────────────────────────────────────

  Future<int> insertFavorite(MealFavorite f) =>
      _insert('meal_favorites', f.toMap());

  Future<int> updateFavorite(MealFavorite f) =>
      _update('meal_favorites', f.toMap(), f.id!);

  Future<int> deleteFavorite(int id) => _delete('meal_favorites', id);

  Future<List<MealFavorite>> getFavorites(String profileId) async {
    final rows = await (await _db).query('meal_favorites',
        where: _live('profileId = ?'),
        whereArgs: [profileId],
        orderBy: 'useCount DESC, createdAt DESC');
    return rows.map(MealFavorite.fromMap).toList();
  }

  Future<void> bumpFavoriteUse(int id) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE meal_favorites SET useCount = useCount + 1, '
        "pendingSync = 1, syncUpdatedAt = ? WHERE id = ?",
        [_now(), id]);
    _sync?.pushSoon();
  }

  // ── Suggestions ──────────────────────────────────────────────────────────

  Future<int> insertSuggestion(SuggestionEntry e) =>
      _insert('suggestion_history', e.toMap());

  /// Past AI suggestions, newest first — powers the suggestion history screen.
  Future<List<SuggestionEntry>> getSuggestions({int limit = 100}) async {
    final rows = await (await _db).query('suggestion_history',
        where: _live(), orderBy: 'timestamp DESC', limit: limit);
    return rows.map(SuggestionEntry.fromMap).toList();
  }

  // ── Aggregates ───────────────────────────────────────────────────────────

  Future<DailySummary> getDailySummary([DateTime? day]) async {
    final date = dateKey(day ?? DateTime.now());
    return DailySummary(
      date: date,
      meals: await getMealsForDate(date),
      workouts: await getWorkoutsForDate(date),
      sleep: await getSleepForDate(date),
      steps: await getStepsForDate(date),
      weight: await getWeightForDate(date),
    );
  }

  /// Distinct dates (newest first) that have any entry, for the History screen.
  Future<List<String>> getRecentDates({int days = 7}) async {
    final db = await _db;
    final since = _since(days);
    final set = <String>{};
    for (final t in [
      'meal_entries',
      'workout_entries',
      'sleep_entries',
      'weight_entries',
      'steps_entries'
    ]) {
      final rows = await db.rawQuery(
          'SELECT DISTINCT date FROM $t WHERE date >= ? AND syncDeleted = 0',
          [since]);
      set.addAll(rows.map((r) => r['date'] as String));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// All logged days (for streak calculation), newest first.
  Future<List<String>> mealLoggedDates() async {
    final rows = await (await _db).rawQuery(
        'SELECT DISTINCT date FROM meal_entries WHERE syncDeleted = 0 '
        'ORDER BY date DESC');
    return rows.map((r) => r['date'] as String).toList();
  }
}
