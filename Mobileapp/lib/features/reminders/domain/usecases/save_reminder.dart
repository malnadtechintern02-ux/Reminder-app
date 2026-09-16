import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';
import '../../../../core/services/notification_service.dart';

class SaveReminderUseCase {
  final ReminderRepository repository;
  final NotificationService notificationService;

  SaveReminderUseCase(this.repository, this.notificationService);

  Future<void> call(Reminder reminder) async {
    await repository.saveReminder(reminder);

    await notificationService.cancelNotification(reminder.id);

    if (!reminder.isCompleted) {
      if (reminder.isRepeating && reminder.repeatType != RepeatType.none) {
        await notificationService.scheduleRepeatingNotification(
          reminder: reminder,
        );
      } else if (reminder.scheduledAt.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
        await notificationService.scheduleNotification(
          reminder: reminder,
        );
      }
    }
  }
}
