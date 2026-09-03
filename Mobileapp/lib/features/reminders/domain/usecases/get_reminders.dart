import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class GetRemindersUseCase {
  final ReminderRepository repository;

  GetRemindersUseCase(this.repository);

  Future<List<Reminder>> call() async {
    return await repository.getReminders();
  }
}
