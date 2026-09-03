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

// Repositories
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepositoryImpl();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl();
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

// Categories provider
final categoriesFutureProvider = FutureProvider<List<Category>>((ref) async {
  return await ref.watch(categoryRepositoryProvider).getCategories();
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

  ReminderListNotifier(
    this._getReminders,
    this._saveReminder,
    this._deleteReminder,
    this._toggleCompletion,
  ) : super(ReminderListState(reminders: [], isLoading: true, searchQuery: '')) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    try {
      state = state.copyWith(isLoading: true);
      final list = await _getReminders();
      state = state.copyWith(reminders: list, isLoading: false);
      _syncToServer(list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _syncToServer(List<Reminder> list) async {
    // Fire and forget sync to keep admin panel updated
    ApiSyncService.syncReminders(list);
  }

  Future<void> saveReminder(Reminder reminder) async {
    try {
      await _saveReminder(reminder);
      await loadReminders();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _deleteReminder(id);
      await loadReminders();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
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
