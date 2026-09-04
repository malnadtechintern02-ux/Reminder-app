import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class SqliteDatabase {
  static final SqliteDatabase instance = SqliteDatabase._init();
  static Database? _database;

  SqliteDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reminder_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE reminders ADD COLUMN end_time TEXT');
      await db.execute('ALTER TABLE reminders ADD COLUMN has_alarm INTEGER NOT NULL DEFAULT 1 CHECK (has_alarm IN (0, 1))');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE reminders ADD COLUMN alarm_enabled INTEGER NOT NULL DEFAULT 0 CHECK (alarm_enabled IN (0, 1))');
      await db.execute('ALTER TABLE reminders ADD COLUMN alarm_sound_enabled INTEGER NOT NULL DEFAULT 1 CHECK (alarm_sound_enabled IN (0, 1))');
      await db.execute('ALTER TABLE reminders ADD COLUMN alarm_vibration_enabled INTEGER NOT NULL DEFAULT 1 CHECK (alarm_vibration_enabled IN (0, 1))');
      await db.execute('ALTER TABLE reminders ADD COLUMN snooze_minutes INTEGER NOT NULL DEFAULT 5');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE reminders ADD COLUMN warning_enabled INTEGER NOT NULL DEFAULT 1 CHECK (warning_enabled IN (0, 1))');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE reminders ADD COLUMN ringtone TEXT');
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL
      )
    ''');

    // Create reminders table
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        scheduled_at TEXT NOT NULL,
        end_time TEXT,
        category_id TEXT NOT NULL,
        priority TEXT NOT NULL,
        is_completed INTEGER NOT NULL CHECK (is_completed IN (0, 1)),
        is_repeating INTEGER NOT NULL CHECK (is_repeating IN (0, 1)),
        repeat_type TEXT NOT NULL,
        has_alarm INTEGER NOT NULL DEFAULT 1 CHECK (has_alarm IN (0, 1)),
        alarm_enabled INTEGER NOT NULL DEFAULT 0 CHECK (alarm_enabled IN (0, 1)),
        alarm_sound_enabled INTEGER NOT NULL DEFAULT 1 CHECK (alarm_sound_enabled IN (0, 1)),
        alarm_vibration_enabled INTEGER NOT NULL DEFAULT 1 CHECK (alarm_vibration_enabled IN (0, 1)),
        snooze_minutes INTEGER NOT NULL DEFAULT 5,
        warning_enabled INTEGER NOT NULL DEFAULT 1 CHECK (warning_enabled IN (0, 1)),
        ringtone TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_reminders_scheduled_at ON reminders (scheduled_at)');
    await db.execute('CREATE INDEX idx_reminders_category_id ON reminders (category_id)');

    // Seed default categories
    await _seedDefaultCategories(db);
  }

  Future _seedDefaultCategories(Database db) async {
    final defaultCategories = [
      {'id': 'work', 'name': 'Work', 'icon': 'work', 'color': '#2196F3'},
      {'id': 'personal', 'name': 'Personal', 'icon': 'person', 'color': '#4CAF50'},
      {'id': 'study', 'name': 'Study', 'icon': 'book', 'color': '#9C27B0'},
      {'id': 'shopping', 'name': 'Shopping', 'icon': 'shopping_cart', 'color': '#FF9800'},
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
