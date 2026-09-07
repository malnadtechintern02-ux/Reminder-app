import '../entities/reminder.dart';

abstract class PriorityRepository {
  Future<List<Priority>> getPriorities({bool forceSync = false});
  Future<void> syncPriorities();
}
