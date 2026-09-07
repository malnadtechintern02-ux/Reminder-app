import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/priority_repository.dart';
import '../../../../core/database/sqlite_database.dart';
import '../../../../core/network/api_sync_service.dart';

class PriorityRepositoryImpl implements PriorityRepository {
  final SqliteDatabase _databaseHelper;

  PriorityRepositoryImpl({SqliteDatabase? databaseHelper})
      : _databaseHelper = databaseHelper ?? SqliteDatabase.instance;

  @override
  Future<List<Priority>> getPriorities({bool forceSync = false}) async {
    final db = await _databaseHelper.database;
    await _ensureTableExists(db);

    final existingMaps = await db.query('priorities', orderBy: 'level ASC');
    if (forceSync || existingMaps.isEmpty) {
      try {
        await syncPriorities();
      } catch (e) {
        debugPrint('Priority initial sync error: $e');
      }
    } else {
      syncPriorities().catchError((e) {
        debugPrint('Priority background sync error: $e');
      });
    }

    final List<Map<String, dynamic>> maps = await db.query('priorities', orderBy: 'level ASC');
    if (maps.isEmpty) {
      return Priority.defaultPriorities;
    }
    return maps.map((map) => Priority.fromMap(map)).toList();
  }

  @override
  Future<void> syncPriorities() async {
    try {
      final baseUrl = await ApiSyncService.getBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/content.php?type=priorities'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          if (list.isNotEmpty) {
            final db = await _databaseHelper.database;
            await _ensureTableExists(db);

            final batch = db.batch();
            for (final p in list) {
              final id = p['id'].toString();
              final status = p['status'];
              if (status != null && (status == 0 || status == '0')) {
                batch.delete('priorities', where: 'id = ?', whereArgs: [id]);
                continue;
              }

              final name = p['name']?.toString() ?? 'Low';
              final level = int.tryParse(p['level']?.toString() ?? '1') ?? 1;

              batch.insert(
                'priorities',
                {
                  'id': id,
                  'name': name,
                  'level': level,
                  'status': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to sync priorities from server: $e');
    }
  }

  Future<void> _ensureTableExists(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS priorities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        level INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }
}
