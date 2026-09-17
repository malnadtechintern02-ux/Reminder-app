import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/features/reminders/data/models/reminder_model.dart';
import 'package:reminder_app/features/reminders/domain/entities/reminder.dart';

void main() {
  test('App logo asset is present and loadable', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final byteData = await rootBundle.load('assets/images/logo.png');
    expect(byteData.lengthInBytes, greaterThan(0));
  });
  group('ReminderModel Serialization Tests', () {
    final reminderDate = DateTime(2026, 8, 29, 12, 0);
    final creationDate = DateTime(2026, 8, 29, 10, 0);

    final testReminder = Reminder(
      id: 'test-uuid-123',
      title: 'Buy Groceries',
      description: 'Milk and bread',
      scheduledAt: reminderDate,
      categoryId: 'shopping',
      priority: Priority.high,
      isCompleted: false,
      isRepeating: true,
      repeatType: RepeatType.weekly,
      hasAlarm: true,
      alarmEnabled: true,
      alarmSoundEnabled: true,
      alarmVibrationEnabled: true,
      snoozeMinutes: 5,
      warningEnabled: true,
      createdAt: creationDate,
    );

    test('should convert to Map correctly', () {
      final model = ReminderModel.fromEntity(testReminder);
      final map = model.toMap();

      expect(map['id'], 'test-uuid-123');
      expect(map['title'], 'Buy Groceries');
      expect(map['description'], 'Milk and bread');
      expect(map['scheduled_at'], reminderDate.toIso8601String());
      expect(map['category_id'], 'shopping');
      expect(map['priority'], 'high');
      expect(map['is_completed'], 0);
      expect(map['is_repeating'], 1);
      expect(map['repeat_type'], 'weekly');
      expect(map['has_alarm'], 1);
      expect(map['alarm_enabled'], 1);
      expect(map['alarm_sound_enabled'], 1);
      expect(map['alarm_vibration_enabled'], 1);
      expect(map['snooze_minutes'], 5);
      expect(map['warning_enabled'], 1);
      expect(map['created_at'], creationDate.toIso8601String());
    });

    test('should construct from Map correctly', () {
      final map = {
        'id': 'test-uuid-123',
        'title': 'Buy Groceries',
        'description': 'Milk and bread',
        'scheduled_at': reminderDate.toIso8601String(),
        'category_id': 'shopping',
        'priority': 'high',
        'is_completed': 0,
        'is_repeating': 1,
        'repeat_type': 'weekly',
        'has_alarm': 1,
        'alarm_enabled': 1,
        'alarm_sound_enabled': 1,
        'alarm_vibration_enabled': 1,
        'snooze_minutes': 5,
        'warning_enabled': 1,
        'created_at': creationDate.toIso8601String(),
      };

      final model = ReminderModel.fromMap(map);

      expect(model.id, 'test-uuid-123');
      expect(model.title, 'Buy Groceries');
      expect(model.description, 'Milk and bread');
      expect(model.scheduledAt, reminderDate);
      expect(model.categoryId, 'shopping');
      expect(model.priority, Priority.high);
      expect(model.isCompleted, false);
      expect(model.isRepeating, true);
      expect(model.repeatType, RepeatType.weekly);
      expect(model.hasAlarm, true);
      expect(model.alarmEnabled, true);
      expect(model.alarmSoundEnabled, true);
      expect(model.alarmVibrationEnabled, true);
      expect(model.snoozeMinutes, 5);
      expect(model.warningEnabled, true);
      expect(model.createdAt, creationDate);
    });
  });
}
