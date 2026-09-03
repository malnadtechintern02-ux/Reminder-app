import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/reminder_list_provider.dart';
import '../../domain/entities/reminder.dart';
import '../widgets/category_selector.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../settings/providers/settings_provider.dart';

class ReminderFormScreen extends ConsumerStatefulWidget {
  final String? reminderId;

  const ReminderFormScreen({
    super.key,
    this.reminderId,
  });

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _descController;
  
  String? _selectedCategoryId;
  Priority _priority = Priority.low;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  TimeOfDay? _selectedEndTime;
  
  bool _isRepeating = false;
  RepeatType _repeatType = RepeatType.none;
  bool _hasAlarm = true; // Maps to basic notifications
  bool _alarmEnabled = false;
  bool _alarmSoundEnabled = true;
  bool _alarmVibrationEnabled = true;
  int _snoozeMinutes = 5;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _isEdit = widget.reminderId != null;

    // Post frame callback to populate editing fields
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEdit) {
        final reminderState = ref.read(reminderListNotifierProvider);
        final reminder = reminderState.reminders.firstWhere(
          (r) => r.id == widget.reminderId,
          orElse: () => throw Exception('Reminder not found'),
        );

        setState(() {
          _titleController.text = reminder.title;
          _descController.text = reminder.description ?? '';
          _selectedCategoryId = reminder.categoryId;
          _priority = reminder.priority;
          _selectedDate = reminder.scheduledAt;
          _selectedTime = TimeOfDay.fromDateTime(reminder.scheduledAt);
          if (reminder.endTime != null) {
            _selectedEndTime = TimeOfDay.fromDateTime(reminder.endTime!);
          }
          _isRepeating = reminder.isRepeating;
          _repeatType = reminder.repeatType;
          _hasAlarm = reminder.hasAlarm;
          _alarmEnabled = reminder.alarmEnabled;
          _alarmSoundEnabled = reminder.alarmSoundEnabled;
          _alarmVibrationEnabled = reminder.alarmVibrationEnabled;
          _snoozeMinutes = reminder.snoozeMinutes;
        });
      } else {
        // Set default category and settings for new reminder
        final categoriesAsync = ref.read(categoriesFutureProvider);
        categoriesAsync.whenData((categories) {
          if (categories.isNotEmpty && _selectedCategoryId == null) {
            setState(() {
              _selectedCategoryId = categories.first.id;
            });
          }
        });
        
        final settings = ref.read(settingsNotifierProvider);
        setState(() {
          _hasAlarm = settings.vibrateOnAlarm;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Validate that schedule time is in the future for one-time alerts
    if (!_isRepeating && scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a date/time in the future.')),
      );
      return;
    }

    DateTime? endDateTime;
    if (_selectedEndTime != null) {
      endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );
      if (endDateTime.isBefore(scheduledDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
        return;
      }
    }

    // Ask for notification permission with user consent (only if not already granted)
    await PermissionHelper.requestNotificationPermissionWithConsent(context);

    if (!mounted) return;

    final reminder = Reminder(
      id: _isEdit ? widget.reminderId! : const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      scheduledAt: scheduledDateTime,
      endTime: endDateTime,
      categoryId: _selectedCategoryId!,
      priority: _priority,
      isCompleted: false,
      isRepeating: _isRepeating,
      repeatType: _isRepeating ? _repeatType : RepeatType.none,
      hasAlarm: _hasAlarm,
      alarmEnabled: _alarmEnabled,
      alarmSoundEnabled: _alarmSoundEnabled,
      alarmVibrationEnabled: _alarmVibrationEnabled,
      snoozeMinutes: _snoozeMinutes,
      createdAt: _isEdit
          ? ref.read(reminderListNotifierProvider).reminders.firstWhere((r) => r.id == widget.reminderId).createdAt
          : DateTime.now(),
    );

    ref.read(reminderListNotifierProvider.notifier).saveReminder(reminder);
    if (!mounted) return;
    context.pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Reminder updated successfully' : 'Reminder saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Reminder' : 'New Reminder'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (categories) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'What do you want to remember?',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add details or notes...',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category Selector
              CategorySelector(
                categories: categories,
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: (id) {
                  setState(() {
                    _selectedCategoryId = id;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Priority Selector
              CrossPriorityWidget(
                currentPriority: _priority,
                onChanged: (p) {
                  setState(() {
                    _priority = p;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Date and Time Row
              Text(
                'Schedule Alert',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: theme.cardColor,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: theme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date', style: theme.textTheme.bodyMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat.yMMMd().format(_selectedDate),
                                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      color: theme.cardColor,
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, color: theme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Time', style: theme.textTheme.bodyMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedTime.format(context),
                                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      color: theme.cardColor,
                      child: InkWell(
                        onTap: _pickEndTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.update_rounded, color: theme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('End', style: theme.textTheme.bodyMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedEndTime?.format(context) ?? 'None',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedEndTime == null ? theme.colorScheme.outline : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Alarm Toggle Section
              Card(
                color: theme.cardColor,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Full-Screen Alarm', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Wake device & ring loudly'),
                      value: _alarmEnabled,
                      onChanged: (val) {
                        setState(() {
                          _alarmEnabled = val;
                        });
                      },
                    ),
                    if (_alarmEnabled) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Alarm Sound'),
                        value: _alarmSoundEnabled,
                        onChanged: (val) {
                          setState(() {
                            _alarmSoundEnabled = val;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Vibration'),
                        value: _alarmVibrationEnabled,
                        onChanged: (val) {
                          setState(() {
                            _alarmVibrationEnabled = val;
                          });
                        },
                      ),
                      ListTile(
                        title: const Text('Snooze Duration'),
                        trailing: DropdownButton<int>(
                          value: _snoozeMinutes,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('5 minutes')),
                            DropdownMenuItem(value: 10, child: Text('10 minutes')),
                            DropdownMenuItem(value: 15, child: Text('15 minutes')),
                            DropdownMenuItem(value: 30, child: Text('30 minutes')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _snoozeMinutes = val;
                              });
                            }
                          },
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Repeating Row
              Card(
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Repeat Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Configure recurrence pattern'),
                        value: _isRepeating,
                        onChanged: (val) {
                          setState(() {
                            _isRepeating = val;
                            if (val && _repeatType == RepeatType.none) {
                              _repeatType = RepeatType.daily;
                            }
                          });
                        },
                      ),
                      if (_isRepeating) ...[
                        const Divider(height: 1),
                        DropdownButtonFormField<RepeatType>(
                          initialValue: _repeatType == RepeatType.none ? RepeatType.daily : _repeatType,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: RepeatType.daily, child: Text('Every Day')),
                            DropdownMenuItem(value: RepeatType.weekly, child: Text('Every Week')),
                            DropdownMenuItem(value: RepeatType.monthly, child: Text('Every Month')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _repeatType = val;
                              });
                            }
                          },
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _saveForm,
                child: Text(
                  _isEdit ? 'Save Changes' : 'Create Reminder',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

class CrossPriorityWidget extends StatelessWidget {
  final Priority currentPriority;
  final ValueChanged<Priority> onChanged;

  const CrossPriorityWidget({
    super.key,
    required this.currentPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorities = Priority.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority Level',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: priorities.map((p) {
            final isSelected = p == currentPriority;
            Color priorityColor;
            switch (p) {
              case Priority.high:
                priorityColor = theme.colorScheme.error;
                break;
              case Priority.medium:
                priorityColor = Colors.amber;
                break;
              case Priority.low:
                priorityColor = theme.colorScheme.secondary;
                break;
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () => onChanged(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? priorityColor.withOpacity(0.18)
                          : theme.colorScheme.onSurface.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? priorityColor : theme.colorScheme.outline.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      p.name.toUpperCase(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isSelected ? priorityColor : theme.textTheme.bodyLarge?.color,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
