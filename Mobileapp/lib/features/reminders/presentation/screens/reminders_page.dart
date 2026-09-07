import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/reminder_list_provider.dart';
import '../../../categories/domain/entities/category.dart';
import '../widgets/reminder_card.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/utils/ui_helpers.dart';

class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<dynamic>> _groupReminders(List<dynamic> reminders) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dayAfterTomorrowStart = todayStart.add(const Duration(days: 2));

    final List<dynamic> overdue = [];
    final List<dynamic> today = [];
    final List<dynamic> tomorrow = [];
    final List<dynamic> upcoming = [];

    for (var r in reminders) {
      if (r.isCompleted) continue;

      if (r.scheduledAt.isBefore(now)) {
        overdue.add(r);
      } else if (r.scheduledAt.isBefore(tomorrowStart)) {
        today.add(r);
      } else if (r.scheduledAt.isBefore(dayAfterTomorrowStart)) {
        tomorrow.add(r);
      } else {
        upcoming.add(r);
      }
    }

    return {
      'Overdue': overdue,
      'Today': today,
      'Tomorrow': tomorrow,
      'Upcoming': upcoming,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeNotifierProvider) == ThemeMode.dark;
    
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final listState = ref.watch(reminderListNotifierProvider);
    final filteredReminders = ref.watch(filteredRemindersProvider);

    final groupedActive = _groupReminders(filteredReminders);
    final completedReminders = filteredReminders.where((r) => r.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () {
              ref.read(themeNotifierProvider.notifier).toggleTheme();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(reminderListNotifierProvider.notifier).setSearchQuery(val);
              },
              decoration: InputDecoration(
                hintText: 'Search reminders...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(reminderListNotifierProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          
          // Horizontal Category filter chips list
          categoriesAsync.when(
            data: (categories) => _buildCategoryFilters(context, categories, listState.selectedCategoryId),
            loading: () => const SizedBox(height: 50),
            error: (e, s) => const SizedBox(height: 50),
          ),

          // Tabs header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.primaryColor.withValues(alpha: 0.12),
              ),
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              tabs: const [
                Tab(child: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
                Tab(child: Text('Completed', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Reminders lists (Tab views)
          Expanded(
            child: listState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(reminderListNotifierProvider.notifier).syncWithServer();
                      ref.invalidate(categoriesFutureProvider);
                      ref.invalidate(prioritiesFutureProvider);
                    },
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Active Reminders
                        _buildActiveTab(context, groupedActive),
                        // Completed Reminders
                        _buildCompletedTab(context, completedReminders),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/reminders/create'),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context, List<Category> categories, String? selectedId) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll ? selectedId == null : selectedId == categories[index - 1].id;

          if (isAll) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                avatar: Icon(Icons.grid_view_rounded, size: 16, color: isSelected ? Colors.white : theme.primaryColor),
                label: const Text('All'),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: theme.primaryColor,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                onSelected: (selected) {
                  ref.read(reminderListNotifierProvider.notifier).selectCategory(null);
                },
              ),
            );
          }

          final category = categories[index - 1];
          final color = parseHexColor(category.color);
          final icon = getCategoryIcon(category.icon);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
              label: Text(category.name),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: color,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(
                color: isSelected ? Colors.transparent : theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              onSelected: (selected) {
                ref.read(reminderListNotifierProvider.notifier).selectCategory(category.id);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context, Map<String, List<dynamic>> grouped) {
    final hasActive = grouped.values.any((list) => list.isNotEmpty);

    if (!hasActive) {
      return _buildEmptyState(
        context,
        Icons.notifications_none_rounded,
        'No active reminders',
        'Create a reminder to get started!',
      );
    }

    final theme = Theme.of(context);
    final sections = ['Overdue', 'Today', 'Tomorrow', 'Upcoming'];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final list = grouped[section] ?? [];

        if (list.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
              child: Text(
                section.toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: section == 'Overdue' ? theme.colorScheme.error : theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  fontSize: 12,
                ),
              ),
            ),
            ...list.map((reminder) => ReminderCard(reminder: reminder)),
          ],
        );
      },
    );
  }

  Widget _buildCompletedTab(BuildContext context, List<dynamic> reminders) {
    if (reminders.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.check_circle_outline_rounded,
        'No completed reminders',
        'Finished reminders will appear here.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        return ReminderCard(reminder: reminders[index]);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      children: [
        const SizedBox(height: 32),
        Center(child: Icon(icon, size: 72, color: theme.colorScheme.outline.withValues(alpha: 0.5))),
        const SizedBox(height: 16),
        Center(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 18))),
        const SizedBox(height: 8),
        Center(
          child: Text(
            subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
