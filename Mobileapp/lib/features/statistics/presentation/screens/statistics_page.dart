import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../reminders/domain/entities/reminder.dart';
import '../../../reminders/presentation/providers/reminder_list_provider.dart';
import '../../../pomodoro/data/pomodoro_repository.dart';
import '../../../../core/utils/ui_helpers.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  int _calculateStreak(List<Reminder> reminders) {
    final completed = reminders.where((r) => r.isCompleted).toList();
    if (completed.isEmpty) return 0;

    final completedDates = completed
        .map((r) => DateTime(r.scheduledAt.year, r.scheduledAt.month, r.scheduledAt.day))
        .toSet();

    final now = DateTime.now();
    DateTime currentCheck = DateTime(now.year, now.month, now.day);

    // If no reminder completed today, check if streak is alive from yesterday
    if (!completedDates.contains(currentCheck)) {
      currentCheck = currentCheck.subtract(const Duration(days: 1));
      if (!completedDates.contains(currentCheck)) {
        return 0;
      }
    }

    int streak = 0;
    while (completedDates.contains(currentCheck)) {
      streak++;
      currentCheck = currentCheck.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final reminders = ref.watch(reminderListNotifierProvider).reminders;
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final totalFocusMinutesAsync = ref.watch(totalFocusMinutesProvider);

    final totalCount = reminders.length;
    final completedCount = reminders.where((r) => r.isCompleted).length;
    final now = DateTime.now();
    final missedCount = reminders
        .where((r) => !r.isCompleted && r.scheduledAt.isBefore(now))
        .length;
    final activeCount = reminders
        .where((r) => !r.isCompleted && !r.scheduledAt.isBefore(now))
        .length;

    final completionRate = totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();
    final streak = _calculateStreak(reminders);

    // Timeframe filters
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final completedToday = reminders
        .where((r) => r.isCompleted && r.scheduledAt.isAfter(todayStart))
        .length;
    final completedThisWeek = reminders
        .where((r) => r.isCompleted && r.scheduledAt.isAfter(weekStart))
        .length;
    final completedThisMonth = reminders
        .where((r) => r.isCompleted && r.scheduledAt.isAfter(monthStart))
        .length;

    final focusMinutes = totalFocusMinutesAsync.maybeWhen(data: (m) => m, orElse: () => 0);
    final focusHoursStr = (focusMinutes / 60).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Analytics & Insights'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Primary Metric Cards Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  theme: theme,
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF43A047),
                  title: 'Completed',
                  value: '$completedCount',
                  subtitle: '$completionRate% success rate',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  theme: theme,
                  icon: Icons.warning_amber_rounded,
                  iconColor: theme.colorScheme.error,
                  title: 'Missed / Overdue',
                  value: '$missedCount',
                  subtitle: '$activeCount upcoming',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  theme: theme,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                  title: 'Day Streak',
                  value: '$streak days',
                  subtitle: streak > 0 ? 'Keep it up! 🔥' : 'Complete a task today',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  theme: theme,
                  icon: Icons.timer_rounded,
                  iconColor: const Color(0xFF1E88E5),
                  title: 'Focus Time',
                  value: '${focusHoursStr}h',
                  subtitle: '$focusMinutes mins logged',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Completion Progress Card
          Card(
            color: theme.cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Completion Rate',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$completionRate%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: completionRate >= 75
                              ? const Color(0xFF43A047)
                              : (completionRate >= 40 ? Colors.orange : theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalCount == 0 ? 0 : completedCount / totalCount,
                      minHeight: 12,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completionRate >= 75
                            ? const Color(0xFF43A047)
                            : (completionRate >= 40 ? Colors.orange : theme.colorScheme.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$completedCount of $totalCount total reminders completed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Time-Range Completion Breakdown
          Card(
            color: theme.cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Breakdown',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeframeColumn(theme, 'Today', completedToday),
                      Container(height: 36, width: 1, color: theme.dividerColor),
                      _buildTimeframeColumn(theme, 'This Week', completedThisWeek),
                      Container(height: 36, width: 1, color: theme.dividerColor),
                      _buildTimeframeColumn(theme, 'This Month', completedThisMonth),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Categories Breakdown
          categoriesAsync.maybeWhen(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return Card(
                color: theme.cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminders by Category',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      ...categories.map((cat) {
                        final catReminders = reminders.where((r) => r.categoryId == cat.id).toList();
                        final catTotal = catReminders.length;
                        if (catTotal == 0) return const SizedBox.shrink();
                        final catCompleted = catReminders.where((r) => r.isCompleted).length;
                        final color = parseHexColor(cat.color);
                        final icon = getCategoryIcon(cat.icon);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          cat.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          '$catCompleted/$catTotal',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: catTotal == 0 ? 0 : catCompleted / catTotal,
                                        minHeight: 6,
                                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                        valueColor: AlwaysStoppedAnimation<Color>(color),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: iconColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeColumn(ThemeData theme, String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
