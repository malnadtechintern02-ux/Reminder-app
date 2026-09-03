import 'package:sqflite/sqflite.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../../../core/database/sqlite_database.dart';
import '../models/reminder_model.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final SqliteDatabase _databaseHelper;

  ReminderRepositoryImpl({SqliteDatabase? databaseHelper})
      : _databaseHelper = databaseHelper ?? SqliteDatabase.instance;

  @override
  Future<List<Reminder>> getReminders() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      orderBy: 'scheduled_at ASC',
    );
    return maps.map((map) => ReminderModel.fromMap(map)).toList();
  }

  @override
  Future<Reminder?> getReminderById(String id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ReminderModel.fromMap(maps.first);
  }

  @override
  Future<void> saveReminder(Reminder reminder) async {
    final db = await _databaseHelper.database;
    final model = ReminderModel.fromEntity(reminder);
    await db.insert(
      'reminders',
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteReminder(String id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateReminderCompletionStatus(String id, bool isCompleted) async {
    final db = await _databaseHelper.database;
    await db.update(
      'reminders',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
