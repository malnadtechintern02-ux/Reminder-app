import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../features/reminders/domain/entities/reminder.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../database/sqlite_database.dart';
import '../services/notification_service.dart';
import '../utils/ui_helpers.dart';

class ApiSyncService {
  // Optional user-configured backend API URL (empty by default for 100% offline mode)
  static const String defaultBaseUrl = '';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_base_url') ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_url', url.trim());
  }

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  static Reminder _parseServerReminder(Map<String, dynamic> map) {
    int parseInt(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultVal;
    }

    bool parseBool(dynamic val, bool defaultVal) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is int) return val == 1;
      final s = val.toString().trim().toLowerCase();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false') return false;
      return defaultVal;
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString().replaceAll(' ', 'T'));
      } catch (_) {
        return DateTime.now();
      }
    }

    return Reminder(
      id: map['id']?.toString() ?? const Uuid().v4(),
      title: map['title']?.toString() ?? 'Untitled',
      description: map['description']?.toString(),
      scheduledAt: parseDate(map['scheduled_at']),
      endTime: map['end_time'] != null && map['end_time'].toString().isNotEmpty
          ? parseDate(map['end_time'])
          : null,
      categoryId: map['category_id']?.toString() ?? '1',
      priority: Priority.fromString(map['priority']?.toString() ?? 'low'),
      isCompleted: parseBool(map['is_completed'], false),
      isRepeating: parseBool(map['is_repeating'], false),
      repeatType: RepeatType.fromString(map['repeat_type']?.toString() ?? 'none'),
      hasAlarm: parseBool(map['has_alarm'], true),
      alarmEnabled: parseBool(map['alarm_enabled'] ?? map['has_alarm'], true),
      alarmSoundEnabled: parseBool(map['alarm_sound_enabled'], true),
      alarmVibrationEnabled: parseBool(map['alarm_vibration_enabled'], true),
      snoozeMinutes: parseInt(map['snooze_minutes'], 5),
      advanceMinutes: parseInt(map['advance_minutes'], parseBool(map['warning_enabled'], true) ? 5 : 0),
      warningEnabled: parseBool(map['warning_enabled'], true),
      vibrationPattern: map['vibration_pattern']?.toString() ?? (parseBool(map['alarm_vibration_enabled'], true) ? 'medium' : 'off'),
      repeatDays: map['repeat_days'] != null
          ? (map['repeat_days'].toString().split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList())
          : null,
      ringtone: map['ringtone']?.toString(),
      createdAt: parseDate(map['created_at']),
    );
  }

  /// Syncs local SQLite with server MySQL in both directions:
  /// 1. Fetches latest reminders from server.
  /// 2. If server has data, merges updates into local SQLite and removes deleted items.
  /// 3. If server is empty and local has items, pushes local items to server.
  /// 4. Synchronizes categories from server into SQLite.
  static Future<List<Reminder>?> performTwoWaySync() async {
    try {
      final baseUrl = await getBaseUrl();
      if (baseUrl.trim().isEmpty) {
        return null;
      }
      final deviceId = await getDeviceId();
      final db = await SqliteDatabase.instance.database;

      // 1. Fetch categories from server if available
      try {
        final catResponse = await http
            .get(Uri.parse('$baseUrl/content.php?type=categories'))
            .timeout(const Duration(seconds: 4));
        if (catResponse.statusCode == 200) {
          final catData = jsonDecode(catResponse.body);
          if (catData['success'] == true && catData['data'] is List) {
            final List categories = catData['data'];
            if (categories.isNotEmpty) {
              // Clean up obsolete string-id default categories
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
              for (int i = 0; i < categories.length; i++) {
                final c = categories[i];
                final id = c['id'].toString();
                final status = c['status'];

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
                  {'id': id, 'name': name, 'icon': icon, 'color': color},
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
              await batch.commit(noResult: true);
            }
          }
        }
      } catch (e) {
        debugPrint('Category sync error: $e');
      }

      // 1b. Fetch priorities from server if available
      try {
        final prioResponse = await http
            .get(Uri.parse('$baseUrl/content.php?type=priorities'))
            .timeout(const Duration(seconds: 4));
        if (prioResponse.statusCode == 200) {
          final prioData = jsonDecode(prioResponse.body);
          if (prioData['success'] == true && prioData['data'] is List) {
            final List prioList = prioData['data'];
            if (prioList.isNotEmpty) {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS priorities (
                  id TEXT PRIMARY KEY,
                  name TEXT NOT NULL,
                  level INTEGER NOT NULL,
                  status INTEGER NOT NULL DEFAULT 1
                )
              ''');

              final batch = db.batch();
              for (final p in prioList) {
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
        debugPrint('Priority sync error: $e');
      }

      // 2. Fetch reminders from server
      final response = await http
          .get(Uri.parse('$baseUrl/sync.php?user_id=$deviceId'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['reminders'] is List) {
          final List serverRaw = data['reminders'];
          final serverReminders = serverRaw
              .map((item) => _parseServerReminder(item as Map<String, dynamic>))
              .toList();

          // Get local reminders
          final localMaps = await db.query('reminders');
          final localReminders = localMaps.map((m) => ReminderModel.fromMap(m)).toList();

          if (serverReminders.isNotEmpty) {
            final serverIds = serverReminders.map((r) => r.id).toSet();

            // Delete local reminders that were deleted on the server (by admin)
            for (final local in localReminders) {
              if (!serverIds.contains(local.id)) {
                await db.delete('reminders', where: 'id = ?', whereArgs: [local.id]);
                await NotificationService.instance.cancelNotification(local.id);
              }
            }

            // Insert / update all server reminders in local SQLite
            for (final server in serverReminders) {
              final model = ReminderModel.fromEntity(server);
              await db.insert('reminders', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              if (!server.isCompleted) {
                if (server.isRepeating) {
                  await NotificationService.instance.scheduleRepeatingNotification(reminder: server);
                } else {
                  await NotificationService.instance.scheduleNotification(reminder: server);
                }
              } else {
                await NotificationService.instance.cancelNotification(server.id);
              }
            }

            // Re-read updated list
            final updatedMaps = await db.query('reminders', orderBy: 'scheduled_at ASC');
            return updatedMaps.map((m) => ReminderModel.fromMap(m)).toList();
          } else if (localReminders.isNotEmpty) {
            // Server has no reminders for this device yet, push local ones
            await syncReminders(localReminders);
            return localReminders;
          }
        }
      }
    } catch (e) {
      debugPrint('Two-way sync error (running offline): $e');
    }
    return null;
  }

  static Future<void> syncReminders(List<Reminder> reminders) async {
    try {
      final baseUrl = await getBaseUrl();
      if (baseUrl.trim().isEmpty) {
        return;
      }
      final deviceId = await getDeviceId();

      final Map<String, dynamic> payload = {
        'user_id': deviceId,
        'reminders': reminders.map((r) => {
          'id': r.id,
          'title': r.title,
          'description': r.description,
          'scheduled_at': r.scheduledAt.toIso8601String(),
          'endTime': r.endTime?.toIso8601String(),
          'categoryId': r.categoryId,
          'priority': r.priority.name,
          'isCompleted': r.isCompleted,
          'isRepeating': r.isRepeating,
          'repeatType': r.repeatType.name,
          'repeat_days': r.repeatDays?.join(','),
          'hasAlarm': r.hasAlarm,
          'alarm_enabled': r.alarmEnabled,
          'alarm_sound_enabled': r.alarmSoundEnabled,
          'alarm_vibration_enabled': r.alarmVibrationEnabled,
          'vibration_pattern': r.vibrationPattern,
          'advance_minutes': r.advanceMinutes,
          'snooze_minutes': r.snoozeMinutes,
          'warning_enabled': r.warningEnabled,
          'ringtone': r.ringtone,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/sync.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        debugPrint('Sync upload complete: ${response.body}');
      } else {
        debugPrint('Sync upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }
}
