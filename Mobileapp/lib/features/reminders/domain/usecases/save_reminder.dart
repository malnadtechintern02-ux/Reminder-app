import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';
import '../../../../core/services/notification_service.dart';

class SaveReminderUseCase {
  final ReminderRepository repository;
  final NotificationService notificationService;

  SaveReminderUseCase(this.repository, this.notificationService);

  Future<void> call(Reminder reminder) async {
    await repository.saveReminder(reminder);

    if (!reminder.isCompleted && reminder.scheduledAt.isAfter(DateTime.now())) {
      if (reminder.isRepeating && reminder.repeatType != RepeatType.none) {
        await notificationService.scheduleRepeatingNotification(
          id: reminder.id,
          title: reminder.title,
          body: reminder.description ?? 'You have a reminder!',
          scheduledDate: reminder.scheduledAt,
          repeatType: reminder.repeatType.name,
        );
      } else {
        await notificationService.scheduleNotification(
          id: reminder.id,
          title: reminder.title,
          body: reminder.description ?? 'You have a reminder!',
          scheduledDate: reminder.scheduledAt,
        );
      }
    } else {
      await notificationService.cancelNotification(reminder.id);
    }
  }
}
