import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/utils/ui_helpers.dart';
import '../../domain/entities/reminder.dart';
import '../providers/reminder_list_provider.dart';
import '../../../settings/providers/settings_provider.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  DateTime _selectedDate = DateTime.now();
  Timer? _minuteTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update current time every minute for the timeline indicator
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _changeDate(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _changeDate(picked);
    }
  }

  void _showQuickActions(BuildContext context, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  reminder.isCompleted ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(reminder.isCompleted ? 'Mark as Pending' : 'Mark as Complete'),
                onTap: () {
                  ref.read(reminderListNotifierProvider.notifier).toggleCompletion(reminder.id, !reminder.isCompleted);
                  Navigator.pop(ctx);
                },
              ),
              if (!reminder.isCompleted)
                ListTile(
                  leading: const Icon(Icons.snooze_rounded, color: Colors.amber),
                  title: Text('Snooze (${ref.read(settingsNotifierProvider).defaultSnoozeDuration}m)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _snoozeReminder(context, reminder, ref.read(settingsNotifierProvider).defaultSnoozeDuration);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/reminders/edit/${reminder.id}');
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  ref.read(reminderListNotifierProvider.notifier).deleteReminder(reminder.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _snoozeReminder(BuildContext ctx, Reminder reminder, int minutes) {
    final newTime = DateTime.now().add(Duration(minutes: minutes));
    final updated = reminder.copyWith(scheduledAt: newTime);
    ref.read(reminderListNotifierProvider.notifier).saveReminder(updated);
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Snoozed for $minutes minutes')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allReminders = ref.watch(reminderListNotifierProvider).reminders;
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    // Filter schedules for the selected date
    final dayReminders = allReminders.where((r) => _isSameDay(r.scheduledAt, _selectedDate)).toList();
    
    // Sort by time
    dayReminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // Stats
    final totalTasks = dayReminders.length;
    final completedTasks = dayReminders.where((r) => r.isCompleted).length;
    final pendingTasks = totalTasks - completedTasks;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              DateFormat('EEEE, MMMM d').format(_selectedDate),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => context.pushNamed(RouteNames.createReminder),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildDateNavigator(theme)),
          SliverToBoxAdapter(child: _buildProgressCard(theme, totalTasks, completedTasks, pendingTasks, progress)),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        body: totalTasks == 0
            ? _buildEmptyState(theme)
            : _buildTimeline(theme, dayReminders, categoriesAsync),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.createReminder),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDateNavigator(ThemeData theme) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDateTab('Yesterday', yesterday, theme),
                  const SizedBox(width: 8),
                  _buildDateTab('Today', today, theme),
                  const SizedBox(width: 8),
                  _buildDateTab('Tomorrow', tomorrow, theme),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.calendar_month_rounded, color: theme.primaryColor),
            onPressed: _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _buildDateTab(String label, DateTime date, ThemeData theme) {
    final isSelected = _isSameDay(_selectedDate, date);
    return GestureDetector(
      onTap: () => _changeDate(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, int total, int completed, int pending, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Plan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildStatColumn('$total Tasks', theme),
                _buildStatColumn('$completed Completed', theme),
                _buildStatColumn('$pending Pending', theme),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📅', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Your schedule is clear', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('No tasks planned for this day.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pushNamed(RouteNames.createReminder),
            icon: const Icon(Icons.add),
            label: const Text('Add Schedule'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme, List<Reminder> reminders, AsyncValue<List<dynamic>> categoriesAsync) {
    final isToday = _isSameDay(_selectedDate, _currentTime);
    
    // Calculate if we need to insert the "NOW" indicator
    List<dynamic> timelineItems = List.from(reminders);
    
    if (isToday) {
      int insertIndex = 0;
      for (int i = 0; i < reminders.length; i++) {
        if (_currentTime.isBefore(reminders[i].scheduledAt)) {
          break;
        }
        insertIndex = i + 1;
      }
      timelineItems.insert(insertIndex, 'NOW');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: timelineItems.length,
      itemBuilder: (context, index) {
        final item = timelineItems[index];

        if (item is String && item == 'NOW') {
          return _buildNowIndicator(theme);
        }

        final reminder = item as Reminder;
        final isLast = index == timelineItems.length - 1;
        
        return _buildTimelineNode(theme, reminder, categoriesAsync, isLast);
      },
    );
  }

  Widget _buildNowIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              DateFormat.jm().format(_currentTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(height: 2, color: theme.colorScheme.error)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NOW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(child: Container(height: 2, color: theme.colorScheme.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(ThemeData theme, Reminder reminder, AsyncValue<List<dynamic>> categoriesAsync, bool isLast) {
    final isMissed = !reminder.isCompleted && reminder.scheduledAt.isBefore(_currentTime) && _isSameDay(reminder.scheduledAt, _currentTime);
    final isCompleted = reminder.isCompleted;

    // Resolve Category
    final category = categoriesAsync.maybeWhen(
      data: (list) {
        final matches = list.where((c) => c.id == reminder.categoryId);
        return matches.isNotEmpty ? matches.first : null;
      },
      orElse: () => null,
    );
    final categoryColor = category != null ? parseHexColor(category.color) : theme.primaryColor;

    // Resolve Priority
    Color priorityColor;
    switch (reminder.priority) {
      case Priority.high: priorityColor = theme.colorScheme.error; break;
      case Priority.medium: priorityColor = Colors.amber; break;
      case Priority.low: priorityColor = theme.colorScheme.secondary; break;
    }

    // Duration calculation
    String durationText = '';
    if (reminder.endTime != null) {
      final diff = reminder.endTime!.difference(reminder.scheduledAt);
      if (diff.inHours > 0 && diff.inMinutes.remainder(60) == 0) {
        durationText = '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
      } else {
        durationText = '${diff.inMinutes} min';
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 20),
                Text(
                  DateFormat.jm().format(reminder.scheduledAt),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                  ),
                ),
                if (reminder.endTime != null)
                  Text(
                    DateFormat.jm().format(reminder.endTime!),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Node Column
          Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? theme.colorScheme.outline : categoryColor,
                  border: Border.all(
                    color: isCompleted ? theme.colorScheme.outline : categoryColor,
                    width: 2,
                  ),
                ),
                child: isCompleted ? Icon(Icons.check, size: 10, color: theme.colorScheme.surface) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(width: 16),
          // Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GestureDetector(
                onTap: () => _showQuickActions(context, reminder),
                child: Opacity(
                  opacity: isCompleted ? 0.6 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMissed ? theme.colorScheme.errorContainer.withOpacity(0.3) : theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMissed ? theme.colorScheme.error.withOpacity(0.5) : Colors.transparent,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reminder.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (isMissed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'MISSED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                            else if (isCompleted)
                              Text('Completed', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                          ],
                        ),
                        if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            reminder.description!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (category != null)
                              _buildChip(category.name, categoryColor, theme),
                            if (durationText.isNotEmpty)
                              _buildChip(durationText, theme.colorScheme.secondary, theme, isOutlined: true),
                            if (reminder.priority == Priority.high)
                              _buildChip('HIGH PRIORITY', priorityColor, theme),
                            if (reminder.hasAlarm)
                              const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.amber),
                            if (reminder.isRepeating)
                              Icon(Icons.repeat_rounded, size: 16, color: theme.colorScheme.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, ThemeData theme, {bool isOutlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: isOutlined ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
