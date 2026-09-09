import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and migrates the local SQLite database.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'health_tracker.db';
  static const _dbVersion = 2;

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
  }

  Future<void> _createPantryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pantry_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT NOT NULL,
        quantity TEXT NOT NULL DEFAULT '',
        isLow INTEGER NOT NULL DEFAULT 0,
        lastUpdated TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        mealType TEXT NOT NULL,
        foodDescription TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        exerciseType TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sleep_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        sleepTime TEXT NOT NULL,
        wakeTime TEXT NOT NULL,
        totalHours REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE weight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weightKg REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE steps_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        stepCount INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE suggestion_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        prompt TEXT NOT NULL,
        response TEXT NOT NULL,
        timestamp TEXT NOT NULL
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
  }
}
