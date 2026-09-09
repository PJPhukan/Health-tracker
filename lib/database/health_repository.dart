import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database_helper.dart';

/// Single repository over all health tables. Keeps DAO-style CRUD in one place
/// since the app is small.
class HealthRepository {
  HealthRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  String _since(int days) {
    final d = DateTime.now().subtract(Duration(days: days - 1));
    return dateKey(DateTime(d.year, d.month, d.day));
  }

  // ---------------- Meals ----------------

  Future<int> insertMeal(MealEntry e) async =>
      (await _db).insert('meal_entries', e.toMap());

  Future<int> deleteMeal(int id) async =>
      (await _db).delete('meal_entries', where: 'id = ?', whereArgs: [id]);

  Future<int> updateMeal(MealEntry entry) async => (await _db).update(
        'meal_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );

  Future<List<MealEntry>> getTodayMeals() =>
      getMealsForDate(dateKey(DateTime.now()));

  Future<List<MealEntry>> getMealsForDate(String date) async {
    final rows = await (await _db).query('meal_entries',
        where: 'date = ?', whereArgs: [date], orderBy: 'timestamp DESC');
    return rows.map(MealEntry.fromMap).toList();
  }

  Future<List<MealEntry>> getRecentMeals({int days = 7}) async {
    final rows = await (await _db).query('meal_entries',
        where: 'date >= ?',
        whereArgs: [_since(days)],
        orderBy: 'date DESC, timestamp DESC');
    return rows.map(MealEntry.fromMap).toList();
  }

  // ---------------- Workouts ----------------

  Future<int> insertWorkout(WorkoutEntry e) async =>
      (await _db).insert('workout_entries', e.toMap());

  Future<int> deleteWorkout(int id) async =>
      (await _db).delete('workout_entries', where: 'id = ?', whereArgs: [id]);

  Future<int> updateWorkout(WorkoutEntry entry) async => (await _db).update(
        'workout_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );

  Future<List<WorkoutEntry>> getTodayWorkouts() =>
      getWorkoutsForDate(dateKey(DateTime.now()));

  Future<List<WorkoutEntry>> getWorkoutsForDate(String date) async {
    final rows = await (await _db).query('workout_entries',
        where: 'date = ?', whereArgs: [date], orderBy: 'timestamp DESC');
    return rows.map(WorkoutEntry.fromMap).toList();
  }

  Future<List<WorkoutEntry>> getRecentWorkouts({int days = 7}) async {
    final rows = await (await _db).query('workout_entries',
        where: 'date >= ?',
        whereArgs: [_since(days)],
        orderBy: 'date DESC, timestamp DESC');
    return rows.map(WorkoutEntry.fromMap).toList();
  }

  // ---------------- Sleep ----------------

  /// One sleep record per day: replace any existing row for the date.
  Future<int> insertSleep(SleepEntry e) async {
    final db = await _db;
    await db.delete('sleep_entries', where: 'date = ?', whereArgs: [e.date]);
    return db.insert('sleep_entries', e.toMap());
  }

  Future<SleepEntry?> getSleepForDate(String date) async {
    final rows = await (await _db)
        .query('sleep_entries', where: 'date = ?', whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : SleepEntry.fromMap(rows.first);
  }

  Future<SleepEntry?> getTodaySleep() =>
      getSleepForDate(dateKey(DateTime.now()));

  Future<int> updateSleep(SleepEntry entry) async => (await _db).update(
        'sleep_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );

  Future<int> deleteSleep(int id) async =>
      (await _db).delete('sleep_entries', where: 'id = ?', whereArgs: [id]);

  Future<List<SleepEntry>> getRecentSleep({int days = 7}) async {
    final rows = await (await _db).query('sleep_entries',
        where: 'date >= ?', whereArgs: [_since(days)], orderBy: 'date DESC');
    return rows.map(SleepEntry.fromMap).toList();
  }

  // ---------------- Weight ----------------

  Future<int> insertWeight(WeightEntry e) async {
    final db = await _db;
    await db.delete('weight_entries', where: 'date = ?', whereArgs: [e.date]);
    return db.insert('weight_entries', e.toMap());
  }

  Future<WeightEntry?> getWeightForDate(String date) async {
    final rows = await (await _db).query('weight_entries',
        where: 'date = ?', whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : WeightEntry.fromMap(rows.first);
  }

  Future<WeightEntry?> getTodayWeight() =>
      getWeightForDate(dateKey(DateTime.now()));

  Future<int> updateWeight(WeightEntry entry) async => (await _db).update(
        'weight_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );

  Future<int> deleteWeight(int id) async =>
      (await _db).delete('weight_entries', where: 'id = ?', whereArgs: [id]);

  Future<List<WeightEntry>> getRecentWeight({int days = 7}) async {
    final rows = await (await _db).query('weight_entries',
        where: 'date >= ?', whereArgs: [_since(days)], orderBy: 'date DESC');
    return rows.map(WeightEntry.fromMap).toList();
  }

  // ---------------- Steps ----------------

  Future<int> insertSteps(StepsEntry e) async {
    final db = await _db;
    await db.delete('steps_entries', where: 'date = ?', whereArgs: [e.date]);
    return db.insert('steps_entries', e.toMap());
  }

  Future<StepsEntry?> getStepsForDate(String date) async {
    final rows = await (await _db)
        .query('steps_entries', where: 'date = ?', whereArgs: [date], limit: 1);
    return rows.isEmpty ? null : StepsEntry.fromMap(rows.first);
  }

  Future<StepsEntry?> getTodaySteps() =>
      getStepsForDate(dateKey(DateTime.now()));

  Future<int> updateSteps(StepsEntry entry) async => (await _db).update(
        'steps_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );

  Future<int> deleteSteps(int id) async =>
      (await _db).delete('steps_entries', where: 'id = ?', whereArgs: [id]);

  Future<List<StepsEntry>> getRecentSteps({int days = 7}) async {
    final rows = await (await _db).query('steps_entries',
        where: 'date >= ?', whereArgs: [_since(days)], orderBy: 'date DESC');
    return rows.map(StepsEntry.fromMap).toList();
  }

  // ---------------- Pantry ----------------

  Future<int> insertPantryItem(PantryItem e) async =>
      (await _db).insert('pantry_items', e.toMap());

  Future<int> updatePantryItem(PantryItem e) async => (await _db).update(
        'pantry_items',
        e.toMap(),
        where: 'id = ?',
        whereArgs: [e.id],
      );

  Future<int> deletePantryItem(int id) async =>
      (await _db).delete('pantry_items', where: 'id = ?', whereArgs: [id]);

  Future<List<PantryItem>> getAllPantryItems() async {
    final rows = await (await _db).query('pantry_items',
        orderBy: 'isLow DESC, itemName COLLATE NOCASE ASC');
    return rows.map(PantryItem.fromMap).toList();
  }

  Future<List<PantryItem>> getLowStockItems() async {
    final rows = await (await _db).query('pantry_items',
        where: 'isLow = 1', orderBy: 'itemName COLLATE NOCASE ASC');
    return rows.map(PantryItem.fromMap).toList();
  }

  // ---------------- Suggestions ----------------

  Future<int> insertSuggestion(SuggestionEntry e) async =>
      (await _db).insert('suggestion_history', e.toMap());

  Future<List<SuggestionEntry>> getRecentSuggestions({int days = 7}) async {
    final rows = await (await _db).query('suggestion_history',
        where: 'date >= ?',
        whereArgs: [_since(days)],
        orderBy: 'timestamp DESC');
    return rows.map(SuggestionEntry.fromMap).toList();
  }

  // ---------------- Aggregates ----------------

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
      final rows = await db
          .rawQuery('SELECT DISTINCT date FROM $t WHERE date >= ?', [since]);
      set.addAll(rows.map((r) => r['date'] as String));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }
}
