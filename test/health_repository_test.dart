import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/database/database_helper.dart';
import 'package:health_tracker/database/health_repository.dart';
import 'package:health_tracker/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Exercises the v3 sync-aware repository against an in-memory SQLite database
// with no SyncService (local-only mode): writes must still tag rows for sync,
// deletes hard-delete, reads skip soft-deleted rows.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper helper;
  late HealthRepository repo;

  setUp(() async {
    // A fresh in-memory DB per test via a unique on-disk-less path.
    databaseFactory = databaseFactoryFfi;
    helper = DatabaseHelper.instance;
    // DatabaseHelper caches its Database; open a throwaway to run schema, then
    // use the repo which shares the singleton.
    repo = HealthRepository(helper: helper);
    // Clean slate: delete every synced table's rows.
    final db = await helper.database;
    for (final t in DatabaseHelper.syncedCollections.keys) {
      await db.delete(t);
    }
  });

  String today() => dateKey(DateTime.now());

  test('meal insert tags syncId + pendingSync, read returns it', () async {
    final id = await repo.insertMeal(MealEntry(
      date: today(),
      mealType: MealType.lunch,
      foodDescription: 'Rice and dal',
      timestamp: DateTime.now().toIso8601String(),
    ));
    expect(id, greaterThan(0));

    final meals = await repo.getTodayMeals();
    expect(meals, hasLength(1));
    expect(meals.first.syncId, isNotNull);
    expect(meals.first.foodDescription, 'Rice and dal');

    final db = await helper.database;
    final raw = await db.query('meal_entries', where: 'id = ?', whereArgs: [id]);
    expect(raw.first['pendingSync'], 1);
    expect(raw.first['syncDeleted'], 0);
  });

  test('meal delete (local-only) hard-deletes and disappears from reads',
      () async {
    final id = await repo.insertMeal(MealEntry(
      date: today(),
      mealType: MealType.dinner,
      foodDescription: 'Soup',
      timestamp: DateTime.now().toIso8601String(),
    ));
    await repo.deleteMeal(id);

    expect(await repo.getTodayMeals(), isEmpty);
    final db = await helper.database;
    final raw = await db.query('meal_entries', where: 'id = ?', whereArgs: [id]);
    expect(raw, isEmpty);
  });

  test('steps use a deterministic per-day syncId and replace in place',
      () async {
    await repo.insertSteps(StepsEntry(date: today(), stepCount: 3000));
    await repo.insertSteps(StepsEntry(date: today(), stepCount: 8000));

    final steps = await repo.getTodaySteps();
    expect(steps!.stepCount, 8000);
    expect(steps.syncId, 'd_${today()}');

    final db = await helper.database;
    final rows = await db.query('steps_entries', where: 'date = ?',
        whereArgs: [today()]);
    expect(rows, hasLength(1)); // replaced, not appended
  });

  test('getRecentDates and getDailySummary ignore soft-deleted rows', () async {
    final id = await repo.insertWorkout(WorkoutEntry(
      date: today(),
      exerciseType: 'Run',
      durationMinutes: 30,
      timestamp: DateTime.now().toIso8601String(),
    ));
    // Simulate a soft delete that hasn't synced yet.
    final db = await helper.database;
    await db.update('workout_entries', {'syncDeleted': 1},
        where: 'id = ?', whereArgs: [id]);

    final summary = await repo.getDailySummary();
    expect(summary.workouts, isEmpty);
    expect(await repo.getRecentDates(days: 7), isNot(contains(today())));
  });

  group('addPantryItemsBatch (pantry onboarding checklist)', () {
    test('inserts every distinct name in one go', () async {
      final added = await repo
          .addPantryItemsBatch(['Rice', 'Onion', 'Toor dal', '  ', '']);
      expect(added, 3); // blanks are dropped
      final items = await repo.getAllPantryItems();
      expect(items.map((i) => i.itemName), containsAll(['Rice', 'Onion', 'Toor dal']));
    });

    test('skips names already in the pantry, case-insensitively', () async {
      await repo.addPantryItemsBatch(['Rice']);
      final added = await repo.addPantryItemsBatch(['rice', 'Onion']);
      expect(added, 1); // only Onion is new
      final items = await repo.getAllPantryItems();
      expect(items, hasLength(2));
    });

    test('a no-op batch (all duplicates) returns 0 and adds nothing', () async {
      await repo.addPantryItemsBatch(['Rice']);
      final added = await repo.addPantryItemsBatch(['Rice']);
      expect(added, 0);
      expect(await repo.getAllPantryItems(), hasLength(1));
    });
  });
}
