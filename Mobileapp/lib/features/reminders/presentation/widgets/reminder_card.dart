import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/reminder.dart';
import '../providers/reminder_list_provider.dart';
import '../../../../core/utils/ui_helpers.dart';
import '../../../settings/providers/settings_provider.dart';

class ReminderCard extends ConsumerWidget {
  final Reminder reminder;

  const ReminderCard({
    super.key,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final category = categoriesAsync.maybeWhen(
      data: (list) {
        final matches = list.where((c) => c.id == reminder.categoryId);
        return matches.isNotEmpty ? matches.first : (list.isNotEmpty ? list.first : null);
      },
      orElse: () => null,
    );

    final categoryColor = category != null ? parseHexColor(category.color) : theme.primaryColor;
    final categoryIcon = category != null ? getCategoryIcon(category.icon) : Icons.label_rounded;

    // Resolve priority color
    final priorityColor = getPriorityColor(reminder.priority, theme);

    final formattedDate = DateFormat.yMMMd().add_jm().format(reminder.scheduledAt);
    final isOverdue = !reminder.isCompleted && reminder.scheduledAt.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.push('/reminders/edit/${reminder.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Checkbox Toggle
                GestureDetector(
                  onTap: () {
                    ref
                        .read(reminderListNotifierProvider.notifier)
                        .toggleCompletion(reminder.id, !reminder.isCompleted);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 2.0),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reminder.isCompleted
                          ? theme.primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: reminder.isCompleted
                            ? theme.primaryColor
                            : theme.colorScheme.outline,
                        width: 2.0,
                      ),
                    ),
                    child: reminder.isCompleted
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                // Title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: reminder.isCompleted
                              ? theme.textTheme.bodyMedium?.color
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Meta Chips Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Category Chip
                          if (category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(categoryIcon, size: 12, color: categoryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Priority Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${reminder.priority.name.toUpperCase()} PRIORITY',
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Recurrence Chip
                          if (reminder.isRepeating)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.replay_rounded,
                                    size: 12,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    reminder.repeatType.name.toUpperCase(),
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Alarm Chip
                          if (reminder.alarmEnabled)
                            Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.notifications_active_rounded,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      reminder.alarmSoundEnabled && reminder.ringtone != null && reminder.ringtone!.isNotEmpty
                                          ? 'ALARM • ${formatRingtoneName(reminder.ringtone).toUpperCase()}'
                                          : 'ALARM',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Time Info Row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isOverdue ? theme.colorScheme.error : theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isOverdue
                                    ? theme.colorScheme.error
                                    : (reminder.isCompleted
                                        ? theme.textTheme.bodyMedium?.color
                                        : theme.colorScheme.secondary),
                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isOverdue) ...[
                            const SizedBox(width: 8),
                            Text(
                              'OVERDUE',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Actions Column (Quick Alarm Toggle & More Menu)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Alarm Toggle
                    IconButton(
                      icon: Icon(
                        reminder.alarmEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        color: reminder.alarmEnabled
                            ? Colors.amber.shade700
                            : theme.disabledColor,
                        size: 22,
                      ),
                      tooltip: reminder.alarmEnabled ? 'Alarm is ON (Tap to turn OFF)' : 'Alarm is OFF (Tap to turn ON)',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.read(reminderListNotifierProvider.notifier).toggleAlarmEnabled(reminder.id, !reminder.alarmEnabled);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(reminder.alarmEnabled ? 'Alarm disabled for "${reminder.title}"' : 'Alarm enabled for "${reminder.title}"'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // More options popup menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (action) {
                        switch (action) {
                          case 'edit':
                            context.push('/reminders/edit/${reminder.id}');
                            break;
                          case 'duplicate':
                            ref.read(reminderListNotifierProvider.notifier).duplicateReminder(reminder);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reminder duplicated (+1 hour)'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            break;
                          case 'test_alarm':
                            context.push('/alarm/${reminder.id}');
                            break;
                          case 'delete':
                            _showDeleteDialog(context, ref);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'test_alarm',
                          child: Row(
                            children: [
                              Icon(Icons.alarm_on_rounded, size: 18, color: Colors.orange),
                              SizedBox(width: 10),
                              Text('Test Alarm Screen'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                              const SizedBox(width: 10),
                              Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: const Text('Delete Reminder?'),
          content: const Text('Are you sure you want to permanently delete this reminder?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                ref.read(reminderListNotifierProvider.notifier).deleteReminder(reminder.id);
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
