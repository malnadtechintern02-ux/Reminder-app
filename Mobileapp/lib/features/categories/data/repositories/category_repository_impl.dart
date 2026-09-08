import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../../../core/database/sqlite_database.dart';
import '../../../../core/network/api_sync_service.dart';
import '../../../../core/utils/ui_helpers.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final SqliteDatabase _databaseHelper;

  CategoryRepositoryImpl({SqliteDatabase? databaseHelper})
      : _databaseHelper = databaseHelper ?? SqliteDatabase.instance;

  @override
  Future<List<Category>> getCategories({bool forceSync = false}) async {
    final db = await _databaseHelper.database;

    // Check if we need to sync from server:
    // Sync if forceSync is requested or if local categories only have old seed data (like string IDs)
    final existingMaps = await db.query('categories');
    final hasOnlyOldSeeds = existingMaps.isNotEmpty &&
        existingMaps.every((m) => int.tryParse(m['id'].toString()) == null);

    if (forceSync || existingMaps.isEmpty || hasOnlyOldSeeds) {
      try {
        await syncCategories();
      } catch (e) {
        debugPrint('Category initial sync error: $e');
      }
    } else {
      // Background sync to ensure fresh categories from admin panel without blocking UI
      syncCategories().catchError((e) {
        debugPrint('Category background sync error: $e');
      });
    }

    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'id ASC');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  @override
  Future<void> syncCategories() async {
    try {
      final baseUrl = await ApiSyncService.getBaseUrl();
      if (baseUrl.trim().isEmpty) return;
      final response = await http
          .get(Uri.parse('$baseUrl/content.php?type=categories'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          if (list.isNotEmpty) {
            final db = await _databaseHelper.database;

            // Migrate reminders referencing old string IDs like 'work' -> '1', 'personal' -> '2' etc.
            final idMap = {
              'work': '1',
              'personal': '2',
              'study': '3',
              'shopping': '6',
            };
            for (final entry in idMap.entries) {
              await db.update(
                'reminders',
                {'category_id': entry.value},
                where: 'category_id = ?',
                whereArgs: [entry.key],
              );
              await db.delete(
                'categories',
                where: 'id = ?',
                whereArgs: [entry.key],
              );
            }

            final batch = db.batch();
            for (int i = 0; i < list.length; i++) {
              final c = list[i];
              final id = c['id'].toString();
              final status = c['status'];

              // If category is disabled/inactive in admin panel, remove it from SQLite
              if (status != null && (status == 0 || status == '0')) {
                batch.delete('categories', where: 'id = ?', whereArgs: [id]);
                continue;
              }

              final name = c['name']?.toString() ?? 'Unnamed';
              final icon = c['icon']?.toString() ?? 'folder';
              final color = (c['color'] != null && c['color'].toString().trim().isNotEmpty)
                  ? c['color'].toString().trim()
                  : resolveDefaultCategoryColor(name, i);

              batch.insert(
                'categories',
                {
                  'id': id,
                  'name': name,
                  'icon': icon,
                  'color': color,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to sync categories from server: $e');
    }
  }
}

