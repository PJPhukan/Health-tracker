import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and migrates the local SQLite database.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'health_tracker.db';
  // v2: pantry_items.  v3: user_profiles.  v4: meal_favorites.
  // v5: sync columns (syncId / pendingSync / syncDeleted / syncUpdatedAt) on
  //     every table that mirrors to Firestore under users/{uid}/.
  static const _dbVersion = 5;

  /// SQLite table -> Firestore collection under `users/{uid}/`.
  static const syncedCollections = <String, String>{
    'meal_entries': 'meals',
    'workout_entries': 'workouts',
    'sleep_entries': 'sleep',
    'weight_entries': 'weight',
    'steps_entries': 'steps',
    'pantry_items': 'pantry_items',
    'meal_favorites': 'meal_favorites',
    'suggestion_history': 'suggestion_history',
  };

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPantryTable(db);
    }
    if (oldVersion < 3) {
      await _createUserProfileTable(db);
    }
    if (oldVersion < 4) {
      await _createMealFavoritesTable(db);
    }
    if (oldVersion < 5) {
      for (final table in syncedCollections.keys) {
        await _addSyncColumns(db, table);
      }
    }
  }

  /// Adds the four sync-bookkeeping columns to an existing table (idempotent).
  Future<void> _addSyncColumns(Database db, String table) async {
    final cols = {
      for (final row in await db.rawQuery('PRAGMA table_info($table)'))
        row['name'] as String
    };
    Future<void> add(String name, String decl) async {
      if (!cols.contains(name)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $name $decl');
      }
    }

    await add('syncId', 'TEXT');
    await add('pendingSync', 'INTEGER NOT NULL DEFAULT 0');
    await add('syncDeleted', 'INTEGER NOT NULL DEFAULT 0');
    await add('syncUpdatedAt', 'TEXT');
  }

  /// Column fragment appended to every synced table in [_onCreate].
  static const _syncColumns = '''
        syncId TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 0,
        syncDeleted INTEGER NOT NULL DEFAULT 0,
        syncUpdatedAt TEXT''';

  Future<void> _createPantryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pantry_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT NOT NULL,
        quantity TEXT NOT NULL DEFAULT '',
        isLow INTEGER NOT NULL DEFAULT 0,
        lastUpdated TEXT NOT NULL,
$_syncColumns
      )
    ''');
  }

  /// One row per account (plus the "local" pseudo-user). Mirrors the Firestore
  /// `users/{uid}` document so profile + goals are available offline.
  Future<void> _createUserProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        profileId TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMealFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profileId TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        mealType TEXT NOT NULL DEFAULT 'snack',
        useCount INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
$_syncColumns
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_meal_favorites_profile '
        'ON meal_favorites(profileId)');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        mealType TEXT NOT NULL,
        foodDescription TEXT NOT NULL,
        timestamp TEXT NOT NULL,
$_syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        exerciseType TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL,
$_syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE sleep_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        sleepTime TEXT NOT NULL,
        wakeTime TEXT NOT NULL,
        totalHours REAL NOT NULL,
$_syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weightKg REAL NOT NULL,
$_syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE steps_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        stepCount INTEGER NOT NULL,
$_syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE suggestion_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        prompt TEXT NOT NULL,
        response TEXT NOT NULL,
        timestamp TEXT NOT NULL,
$_syncColumns
      )
    ''');

    for (final t in [
      'meal_entries',
      'workout_entries',
      'sleep_entries',
      'weight_entries',
      'steps_entries',
      'suggestion_history'
    ]) {
      await db.execute('CREATE INDEX idx_${t}_date ON $t(date)');
    }

    await _createPantryTable(db);
    await _createUserProfileTable(db);
    await _createMealFavoritesTable(db);
  }
}
