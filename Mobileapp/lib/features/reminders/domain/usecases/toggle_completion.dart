import '../repositories/reminder_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../entities/reminder.dart';

class ToggleCompletionUseCase {
  final ReminderRepository repository;
  final NotificationService notificationService;

  ToggleCompletionUseCase(this.repository, this.notificationService);

  Future<void> call(String id, bool isCompleted) async {
    await repository.updateReminderCompletionStatus(id, isCompleted);
    final reminder = await repository.getReminderById(id);

    if (reminder != null) {
      if (isCompleted) {
        await notificationService.cancelNotification(id);
      } else {
        if (reminder.scheduledAt.isAfter(DateTime.now())) {
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
        }
      }
    }
  }
}
