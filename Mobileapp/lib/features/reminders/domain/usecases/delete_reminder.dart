import '../repositories/reminder_repository.dart';
import '../../../../core/services/notification_service.dart';

class DeleteReminderUseCase {
  final ReminderRepository repository;
  final NotificationService notificationService;

  DeleteReminderUseCase(this.repository, this.notificationService);

  Future<void> call(String id) async {
    await notificationService.cancelNotification(id);
    await repository.deleteReminder(id);
  }
}
