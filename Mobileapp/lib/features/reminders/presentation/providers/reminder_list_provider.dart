import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/usecases/get_reminders.dart';
import '../../domain/usecases/save_reminder.dart';
import '../../domain/usecases/delete_reminder.dart';
import '../../domain/usecases/toggle_completion.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/network/api_sync_service.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../categories/data/repositories/category_repository_impl.dart';
import '../../domain/repositories/priority_repository.dart';
import '../../data/repositories/priority_repository_impl.dart';

// Repositories
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepositoryImpl();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl();
});

final priorityRepositoryProvider = Provider<PriorityRepository>((ref) {
  return PriorityRepositoryImpl();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

// Use Cases
final getRemindersUseCaseProvider = Provider<GetRemindersUseCase>((ref) {
  return GetRemindersUseCase(ref.watch(reminderRepositoryProvider));
});

final saveReminderUseCaseProvider = Provider<SaveReminderUseCase>((ref) {
  return SaveReminderUseCase(
    ref.watch(reminderRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

final deleteReminderUseCaseProvider = Provider<DeleteReminderUseCase>((ref) {
  return DeleteReminderUseCase(
    ref.watch(reminderRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

final toggleCompletionUseCaseProvider = Provider<ToggleCompletionUseCase>((ref) {
  return ToggleCompletionUseCase(
    ref.watch(reminderRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

// Categories & Priorities providers
final categoriesFutureProvider = FutureProvider<List<Category>>((ref) async {
  return await ref.watch(categoryRepositoryProvider).getCategories();
});

final prioritiesFutureProvider = FutureProvider<List<Priority>>((ref) async {
  return await ref.watch(priorityRepositoryProvider).getPriorities();
});

// State definitions
class ReminderListState {
  final List<Reminder> reminders;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String? selectedCategoryId;

  ReminderListState({
    required this.reminders,
    required this.isLoading,
    this.errorMessage,
    required this.searchQuery,
    this.selectedCategoryId,
  });

  ReminderListState copyWith({
    List<Reminder>? reminders,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? selectedCategoryId,
    bool clearCategory = false,
  }) {
    return ReminderListState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }
}

// State Notifier
class ReminderListNotifier extends StateNotifier<ReminderListState> {
  final GetRemindersUseCase _getReminders;
  final SaveReminderUseCase _saveReminder;
  final DeleteReminderUseCase _deleteReminder;
  final ToggleCompletionUseCase _toggleCompletion;
  final Ref _ref;

  ReminderListNotifier(
    this._getReminders,
    this._saveReminder,
    this._deleteReminder,
    this._toggleCompletion,
    this._ref,
  ) : super(ReminderListState(reminders: [], isLoading: true, searchQuery: '')) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    try {
      state = state.copyWith(isLoading: true);
      final list = await _getReminders();
      state = state.copyWith(reminders: list, isLoading: false);
      // Synchronize stored alarms with native AlarmManager
      NotificationService.instance.rescheduleAllActiveReminders(list);
      await syncWithServer();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> syncWithServer() async {
    try {
      final syncedList = await ApiSyncService.performTwoWaySync();
      if (syncedList != null) {
        state = state.copyWith(reminders: syncedList);
        NotificationService.instance.rescheduleAllActiveReminders(syncedList);
      }
      _ref.invalidate(categoriesFutureProvider);
      _ref.invalidate(prioritiesFutureProvider);
    } catch (e) {
      // Offline fallback
    }
  }

  Future<void> _syncToServer(List<Reminder> list) async {
    ApiSyncService.syncReminders(list);
  }

  Future<void> saveReminder(Reminder reminder) async {
    // Optimistic update
    final previousReminders = state.reminders;
    final index = previousReminders.indexWhere((r) => r.id == reminder.id);
    final updatedReminders = List<Reminder>.from(previousReminders);
    if (index >= 0) {
      updatedReminders[index] = reminder;
    } else {
      updatedReminders.add(reminder);
    }
    
    // Sort reminders to maintain order
    updatedReminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    
    state = state.copyWith(reminders: updatedReminders);

    try {
      await _saveReminder(reminder);
      // Run sync in the background
      _syncToServer(state.reminders);
    } catch (e) {
      debugPrint('Reminder save failed: $e');
      state = state.copyWith(
        reminders: previousReminders,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deleteReminder(String id) async {
    // Optimistic UI update
    final previousReminders = state.reminders;
    state = state.copyWith(reminders: previousReminders.where((r) => r.id != id).toList());

    try {
      await _deleteReminder(id);
      // We don't await loadReminders() to avoid blocking UI with a full refresh + sync
      // Run sync in the background
      _syncToServer(state.reminders);
    } catch (e) {
      // Rollback on error
      debugPrint('Reminder delete failed: $e');
      state = state.copyWith(
        reminders: previousReminders,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> toggleCompletion(String id, bool isCompleted) async {
    try {
      await _toggleCompletion(id, isCompleted);
      await loadReminders();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectCategory(String? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
  }
}

// Notifier Provider
final reminderListNotifierProvider =
    StateNotifierProvider<ReminderListNotifier, ReminderListState>((ref) {
  return ReminderListNotifier(
    ref.watch(getRemindersUseCaseProvider),
    ref.watch(saveReminderUseCaseProvider),
    ref.watch(deleteReminderUseCaseProvider),
    ref.watch(toggleCompletionUseCaseProvider),
    ref,
  );
});

// Derived Filters
final filteredRemindersProvider = Provider<List<Reminder>>((ref) {
  final state = ref.watch(reminderListNotifierProvider);
  return state.reminders.where((reminder) {
    final matchesQuery = reminder.title.toLowerCase().contains(state.searchQuery.toLowerCase()) ||
        (reminder.description?.toLowerCase().contains(state.searchQuery.toLowerCase()) ?? false);
    final matchesCategory =
        state.selectedCategoryId == null || reminder.categoryId == state.selectedCategoryId;
    return matchesQuery && matchesCategory;
  }).toList();
});
