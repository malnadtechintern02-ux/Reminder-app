import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/features/categories/domain/entities/category.dart';
import 'package:reminder_app/features/reminders/domain/entities/reminder.dart';

void main() {
  group('Category and Snooze Safety Tests', () {
    test('Category model preserves all properties accurately', () {
      final category = Category(
        id: 'cat-123',
        name: 'Work Tasks',
        icon: 'work',
        color: '#4A90E2',
      );

      expect(category.id, 'cat-123');
      expect(category.name, 'Work Tasks');
      expect(category.icon, 'work');
      expect(category.color, '#4A90E2');
    });

    test('Snooze calculation produces future scheduled time and keeps reminder active', () {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'rem-snooze-test',
        title: 'Meeting with Team',
        scheduledAt: now,
        categoryId: 'work',
        priority: Priority.high,
        isCompleted: false,
        isRepeating: false,
        repeatType: RepeatType.none,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 10,
        warningEnabled: true,
        createdAt: now,
      );

      const snoozeMinutes = 10;
      final snoozedTime = now.add(const Duration(minutes: snoozeMinutes));
      final snoozedReminder = reminder.copyWith(
        scheduledAt: snoozedTime,
        isCompleted: false,
      );

      expect(snoozedReminder.scheduledAt.isAfter(now), isTrue);
      expect(snoozedReminder.isCompleted, isFalse);
      expect(snoozedReminder.scheduledAt.difference(now).inMinutes, snoozeMinutes);
    });

    test('Reassigning reminder category preserves all reminder metadata', () {
      final now = DateTime.now();
      final reminder = Reminder(
        id: 'rem-cat-reassign',
        title: 'Study Physics',
        description: 'Read chapter 4',
        scheduledAt: now.add(const Duration(hours: 3)),
        categoryId: 'custom-to-be-deleted',
        priority: Priority.high,
        isCompleted: false,
        isRepeating: false,
        repeatType: RepeatType.none,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 10,
        advanceMinutes: 5,
        warningEnabled: true,
        vibrationPattern: 'medium',
        ringtone: 'morning_breeze',
        createdAt: now,
      );

      const fallbackCategoryId = 'general';
      final reassigned = reminder.copyWith(categoryId: fallbackCategoryId);

      expect(reassigned.id, reminder.id);
      expect(reassigned.title, reminder.title);
      expect(reassigned.description, reminder.description);
      expect(reassigned.scheduledAt, reminder.scheduledAt);
      expect(reassigned.categoryId, fallbackCategoryId);
      expect(reassigned.alarmEnabled, isTrue);
      expect(reassigned.advanceMinutes, 5);
      expect(reassigned.ringtone, 'morning_breeze');
    });
  });
}
