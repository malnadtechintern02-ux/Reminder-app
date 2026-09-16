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
}
