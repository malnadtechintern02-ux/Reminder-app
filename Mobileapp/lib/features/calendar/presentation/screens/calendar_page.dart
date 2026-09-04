import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../reminders/presentation/providers/reminder_list_provider.dart';
import '../../../reminders/domain/entities/reminder.dart';
import '../../../reminders/presentation/widgets/reminder_card.dart';
import '../../../settings/providers/settings_provider.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Reminder> _getEventsForDay(DateTime day, List<Reminder> allReminders) {
    return allReminders.where((r) => _isSameDay(r.scheduledAt, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allReminders = ref.watch(reminderListNotifierProvider).reminders;
    
    final selectedReminders = _getEventsForDay(_selectedDay ?? _focusedDay, allReminders);
    selectedReminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: false,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: TableCalendar<Reminder>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => _isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) => _getEventsForDay(day, allReminders),
              startingDayOfWeek: ref.watch(settingsNotifierProvider).startOfWeekMonday 
                  ? StartingDayOfWeek.monday 
                  : StartingDayOfWeek.sunday,
              daysOfWeekHeight: 28, // Fix clipping of weekday names
              rowHeight: 52,
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                weekendStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),
        ],
        body: selectedReminders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'No events for this day',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: selectedReminders.length,
                itemBuilder: (context, index) {
                  return ReminderCard(reminder: selectedReminders[index]);
                },
              ),
      ),
    );
  }
}
