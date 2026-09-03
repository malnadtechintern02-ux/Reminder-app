import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../features/reminders/domain/entities/reminder.dart';

class ApiSyncService {
  // Use 10.0.2.2 for Android emulator to access localhost, or actual IP for physical device.
  // We'll use a generic variable that can be updated. For web or windows it is just localhost.
  // Assuming Android emulator here based on standard Flutter dev.
  static const String baseUrl = 'http://10.0.2.2/reminder%20app/backend/api';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  static Future<void> syncReminders(List<Reminder> reminders) async {
    try {
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
          'hasAlarm': r.hasAlarm,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/sync.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('Sync complete: ${response.body}');
      } else {
        print('Sync failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }
}
