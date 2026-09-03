import '../entities/reminder.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> getReminders();
  Future<Reminder?> getReminderById(String id);
  Future<void> saveReminder(Reminder reminder);
  Future<void> deleteReminder(String id);
  Future<void> updateReminderCompletionStatus(String id, bool isCompleted);
}
