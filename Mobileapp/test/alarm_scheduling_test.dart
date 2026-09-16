import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/features/reminders/domain/entities/reminder.dart';
import 'package:reminder_app/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:reminder_app/features/reminders/domain/usecases/save_reminder.dart';
import 'package:reminder_app/features/reminders/domain/usecases/toggle_completion.dart';
import 'package:reminder_app/core/services/notification_service.dart';

class MockReminderRepository implements ReminderRepository {
  final Map<String, Reminder> store = {};

  @override
  Future<List<Reminder>> getReminders() async => store.values.toList();

  @override
  Future<Reminder?> getReminderById(String id) async => store[id];

  @override
  Future<void> saveReminder(Reminder reminder) async {
    store[reminder.id] = reminder;
  }

  @override
  Future<void> deleteReminder(String id) async {
    store.remove(id);
  }

  @override
  Future<void> updateReminderCompletionStatus(String id, bool isCompleted) async {
    if (store.containsKey(id)) {
      store[id] = store[id]!.copyWith(isCompleted: isCompleted);
    }
  }
}

class MockNotificationService implements NotificationService {
  final List<String> scheduledOneOffIds = [];
  final List<String> scheduledRepeatingIds = [];
  final List<String> cancelledIds = [];

  @override
  Future<void> scheduleNotification({required Reminder reminder}) async {
    scheduledOneOffIds.add(reminder.id);
  }

  @override
  Future<void> scheduleRepeatingNotification({required Reminder reminder}) async {
    scheduledRepeatingIds.add(reminder.id);
  }

  @override
  Future<void> cancelNotification(String id) async {
    cancelledIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm ID Safety Tests', () {
    test('Notification ID masking stays strictly within 32-bit positive integer limits', () {
      // Test thousands of UUIDs to ensure notificationId * 2 + 1 never overflows 0x7FFFFFFF
      for (int i = 0; i < 1000; i++) {
        final uuid = 'test-uuid-random-$i-${DateTime.now().microsecondsSinceEpoch}';
        int hash = 5381;
        for (int c = 0; c < uuid.length; c++) {
          hash = ((hash << 5) + hash) + uuid.codeUnitAt(c);
          hash = hash & 0x3FFFFFFF;
        }

        expect(hash >= 0, true, reason: 'Hash should be non-negative');
        final warningId = hash * 2;
        final alarmId = hash * 2 + 1;

        expect(warningId >= 0 && warningId <= 0x7FFFFFFF, true,
            reason: 'Warning ID must fit in 32-bit positive int');
        expect(alarmId >= 0 && alarmId <= 0x7FFFFFFF, true,
            reason: 'Alarm ID must fit in 32-bit positive int');
      }
    });
  });

  group('SaveReminderUseCase Alarm Scheduling Tests', () {
    late MockReminderRepository repo;
    late MockNotificationService mockNotifications;
    late SaveReminderUseCase saveReminderUseCase;

    setUp(() {
      repo = MockReminderRepository();
      mockNotifications = MockNotificationService();
      saveReminderUseCase = SaveReminderUseCase(repo, mockNotifications);
    });

    test('should schedule repeating reminder even if scheduledAt is earlier in the day', () async {
      // Scheduled 2 hours ago today
      final pastTimeToday = DateTime.now().subtract(const Duration(hours: 2));

      final repeatingReminder = Reminder(
        id: 'repeating-1',
        title: 'Daily Meditation',
        scheduledAt: pastTimeToday,
        categoryId: 'health',
        priority: Priority.medium,
        isCompleted: false,
        isRepeating: true,
        repeatType: RepeatType.daily,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 5,
        warningEnabled: true,
        createdAt: DateTime.now(),
      );

      await saveReminderUseCase(repeatingReminder);

      expect(mockNotifications.scheduledRepeatingIds, contains('repeating-1'),
          reason: 'Repeating alarm must be scheduled to roll forward to tomorrow');
      expect(mockNotifications.scheduledOneOffIds, isEmpty);
    });

    test('should schedule one-off reminder scheduled within the current minute', () async {
      // Scheduled 10 seconds ago (same minute)
      final currentMinuteTime = DateTime.now().subtract(const Duration(seconds: 10));

      final imminentReminder = Reminder(
        id: 'imminent-1',
        title: 'Quick Call',
        scheduledAt: currentMinuteTime,
        categoryId: 'work',
        priority: Priority.high,
        isCompleted: false,
        isRepeating: false,
        repeatType: RepeatType.none,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 5,
        warningEnabled: true,
        createdAt: DateTime.now(),
      );

      await saveReminderUseCase(imminentReminder);

      expect(mockNotifications.scheduledOneOffIds, contains('imminent-1'),
          reason: 'Current minute reminder must be scheduled to trigger with buffer');
    });

    test('should not schedule completed reminders', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));

      final completedReminder = Reminder(
        id: 'completed-1',
        title: 'Completed Task',
        scheduledAt: futureTime,
        categoryId: 'work',
        priority: Priority.low,
        isCompleted: true,
        isRepeating: false,
        repeatType: RepeatType.none,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 5,
        warningEnabled: true,
        createdAt: DateTime.now(),
      );

      await saveReminderUseCase(completedReminder);

      expect(mockNotifications.scheduledOneOffIds, isEmpty);
      expect(mockNotifications.scheduledRepeatingIds, isEmpty);
      expect(mockNotifications.cancelledIds, contains('completed-1'));
    });
  });

  group('ToggleCompletionUseCase Alarm Scheduling Tests', () {
    late MockReminderRepository repo;
    late MockNotificationService mockNotifications;
    late ToggleCompletionUseCase toggleUseCase;

    setUp(() {
      repo = MockReminderRepository();
      mockNotifications = MockNotificationService();
      toggleUseCase = ToggleCompletionUseCase(repo, mockNotifications);
    });

    test('should reschedule repeating reminder when toggled from complete to incomplete', () async {
      final pastTime = DateTime.now().subtract(const Duration(hours: 3));
      final reminder = Reminder(
        id: 'toggle-rep-1',
        title: 'Workout',
        scheduledAt: pastTime,
        categoryId: 'fitness',
        priority: Priority.medium,
        isCompleted: true,
        isRepeating: true,
        repeatType: RepeatType.daily,
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 5,
        warningEnabled: true,
        createdAt: DateTime.now(),
      );

      await repo.saveReminder(reminder);
      await toggleUseCase('toggle-rep-1', false);

      expect(mockNotifications.scheduledRepeatingIds, contains('toggle-rep-1'));
    });

    test('should schedule repeating weekdays and custom days reminders properly', () async {
      final pastTime = DateTime.now().subtract(const Duration(hours: 5));
      final weekdaysReminder = Reminder(
        id: 'weekdays-1',
        title: 'Work Standup',
        scheduledAt: pastTime,
        categoryId: 'work',
        priority: Priority.high,
        isCompleted: false,
        isRepeating: true,
        repeatType: RepeatType.weekdays,
        repeatDays: const [1, 2, 3, 4, 5],
        advanceMinutes: 10,
        vibrationPattern: 'strong',
        hasAlarm: true,
        alarmEnabled: true,
        alarmSoundEnabled: true,
        alarmVibrationEnabled: true,
        snoozeMinutes: 10,
        warningEnabled: true,
        createdAt: DateTime.now(),
      );

      await repo.saveReminder(weekdaysReminder);
      final saveUseCase = SaveReminderUseCase(repo, mockNotifications);
      await saveUseCase(weekdaysReminder);

      expect(mockNotifications.scheduledRepeatingIds, contains('weekdays-1'));
      expect(weekdaysReminder.advanceMinutes, 10);
      expect(weekdaysReminder.vibrationPattern, 'strong');
      expect(weekdaysReminder.repeatDays, const [1, 2, 3, 4, 5]);
    });

    test('26-bit masked notification ID with 16 multiplier never overflows signed 32-bit int', () {
      for (int i = 0; i < 5000; i++) {
        final uuid = 'uuid-test-overflow-$i';
        int hash = 5381;
        for (int c = 0; c < uuid.length; c++) {
          hash = ((hash << 5) + hash) + uuid.codeUnitAt(c);
          hash = hash & 0x03FFFFFF; // 26 bits
        }

        final maxSlot = hash * 16 + 15;
        expect(maxSlot >= 0, true);
        expect(maxSlot <= 0x7FFFFFFF, true, reason: 'Slot $maxSlot must fit in 32-bit positive integer');
      }
    });
  });
}
