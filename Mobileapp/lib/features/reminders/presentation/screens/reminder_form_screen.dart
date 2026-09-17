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
import '../../../settings/presentation/screens/ringtone_selection_screen.dart';
import '../../../../core/utils/ui_helpers.dart';

class ReminderFormScreen extends ConsumerStatefulWidget {
  final String? reminderId;
  final DateTime? initialDate;

  const ReminderFormScreen({
    super.key,
    this.reminderId,
    this.initialDate,
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
  List<int> _repeatDays = [];
  int _advanceMinutes = 5;
  String _vibrationPattern = 'medium';
  bool _hasAlarm = true; // Maps to basic notifications
  bool _warningEnabled = true;
  bool _alarmEnabled = false;
  bool _alarmSoundEnabled = true;
  bool _alarmVibrationEnabled = true;
  int _snoozeMinutes = 5;
  String? _selectedRingtone;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _isEdit = widget.reminderId != null;

    if (widget.initialDate != null) {
      final now = DateTime.now();
      _selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
        now.hour + 1,
        0,
      );
      _selectedTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    }

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
          _repeatDays = List<int>.from(reminder.repeatDays ?? [reminder.scheduledAt.weekday]);
          _advanceMinutes = reminder.advanceMinutes;
          _vibrationPattern = reminder.vibrationPattern;
          _hasAlarm = reminder.hasAlarm;
          _warningEnabled = reminder.warningEnabled && reminder.advanceMinutes > 0;
          _alarmEnabled = reminder.alarmEnabled;
          _alarmSoundEnabled = reminder.alarmSoundEnabled;
          _alarmVibrationEnabled = reminder.alarmVibrationEnabled && reminder.vibrationPattern != 'off';
          _snoozeMinutes = reminder.snoozeMinutes;
          _selectedRingtone = reminder.ringtone ?? ref.read(settingsNotifierProvider).defaultRingtone;
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
          _hasAlarm = settings.notificationsEnabled;
          _advanceMinutes = settings.fiveMinuteWarningEnabled ? 5 : 0;
          _warningEnabled = _advanceMinutes > 0;
          _alarmEnabled = settings.vibrateOnAlarm || settings.alarmSoundEnabled;
          _alarmSoundEnabled = settings.alarmSoundEnabled;
          _vibrationPattern = settings.alarmVibrationEnabled ? 'medium' : 'off';
          _alarmVibrationEnabled = _vibrationPattern != 'off';
          _repeatDays = [_selectedDate.weekday];
          _snoozeMinutes = settings.defaultSnoozeDuration;
          _selectedRingtone = settings.defaultRingtone;
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

  Future<void> _pickRingtone() async {
    final defaultTone = ref.read(settingsNotifierProvider).defaultRingtone;
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => RingtoneSelectionScreen(
          initialRingtone: _selectedRingtone ?? defaultTone,
          isSelectingForReminder: true,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedRingtone = selected;
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

    final now = DateTime.now();
    final currentMinuteTruncated = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    // Validate that schedule time is not in the past (allowing current minute which triggers immediately)
    if (!_isRepeating && scheduledDateTime.isBefore(currentMinuteTruncated)) {
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
      repeatDays: _isRepeating && (_repeatType == RepeatType.weekdays || _repeatType == RepeatType.weekends || _repeatType == RepeatType.custom)
          ? _repeatDays
          : null,
      advanceMinutes: _advanceMinutes,
      vibrationPattern: _vibrationPattern,
      hasAlarm: _hasAlarm,
      warningEnabled: _warningEnabled && _advanceMinutes > 0,
      alarmEnabled: _alarmEnabled,
      alarmSoundEnabled: _alarmSoundEnabled,
      alarmVibrationEnabled: _alarmVibrationEnabled && _vibrationPattern != 'off',
      snoozeMinutes: _snoozeMinutes,
      ringtone: _selectedRingtone,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: theme.primaryColor, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat.yMMMd().format(_selectedDate),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Card(
                      color: theme.cardColor,
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, color: theme.primaryColor, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Time', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedTime.format(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Card(
                      color: theme.cardColor,
                      child: InkWell(
                        onTap: _pickEndTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                          child: Row(
                            children: [
                              Icon(Icons.update_rounded, color: theme.primaryColor, size: 18),
                              const SizedBox(width: 6),
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
                    ListTile(
                      leading: Icon(Icons.access_alarm_rounded, color: theme.colorScheme.primary),
                      title: const Text('Advance Notification', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_advanceMinutes == 0 ? 'Off (No advance alert)' : 'Alert $_advanceMinutes minutes before'),
                      trailing: DropdownButton<int>(
                        value: _advanceMinutes,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Off')),
                          DropdownMenuItem(value: 5, child: Text('5m before')),
                          DropdownMenuItem(value: 10, child: Text('10m before')),
                          DropdownMenuItem(value: 15, child: Text('15m before')),
                          DropdownMenuItem(value: 30, child: Text('30m before')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _advanceMinutes = val;
                              _warningEnabled = val > 0;
                            });
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
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
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.music_note_rounded,
                          color: _alarmSoundEnabled ? theme.colorScheme.primary : theme.disabledColor,
                        ),
                        title: Text(
                          'Alarm Ringtone',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _alarmSoundEnabled ? null : theme.disabledColor,
                          ),
                        ),
                        subtitle: Text(
                          _alarmSoundEnabled
                              ? formatRingtoneName(_selectedRingtone ?? ref.read(settingsNotifierProvider).defaultRingtone)
                              : 'Sound is muted (Silent)',
                          style: TextStyle(
                            color: _alarmSoundEnabled ? theme.colorScheme.primary : theme.disabledColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: _alarmSoundEnabled ? null : theme.disabledColor,
                        ),
                        onTap: () {
                          if (!_alarmSoundEnabled) {
                            setState(() {
                              _alarmSoundEnabled = true;
                            });
                          }
                          _pickRingtone();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.vibration_rounded, color: theme.colorScheme.primary),
                        title: const Text('Vibration Pattern', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Pattern: ${_vibrationPattern.toUpperCase()}'),
                        trailing: DropdownButton<String>(
                          value: _vibrationPattern,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'off', child: Text('Off')),
                            DropdownMenuItem(value: 'short', child: Text('Short')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'long', child: Text('Long')),
                            DropdownMenuItem(value: 'strong', child: Text('Strong')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _vibrationPattern = val;
                                _alarmVibrationEnabled = val != 'off';
                              });
                            }
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.snooze_rounded, color: theme.colorScheme.primary),
                        title: const Text('Default Snooze Duration', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            DropdownMenuItem(value: RepeatType.weekdays, child: Text('Weekdays (Mon - Fri)')),
                            DropdownMenuItem(value: RepeatType.weekends, child: Text('Weekends (Sat - Sun)')),
                            DropdownMenuItem(value: RepeatType.weekly, child: Text('Every Week')),
                            DropdownMenuItem(value: RepeatType.monthly, child: Text('Every Month')),
                            DropdownMenuItem(value: RepeatType.custom, child: Text('Custom Days')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _repeatType = val;
                                if (_repeatType == RepeatType.custom && _repeatDays.isEmpty) {
                                  _repeatDays = [_selectedDate.weekday];
                                }
                              });
                            }
                          },
                        ),
                        if (_repeatType == RepeatType.custom) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Repeat On Days:',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              {'day': 1, 'label': 'Mon'},
                              {'day': 2, 'label': 'Tue'},
                              {'day': 3, 'label': 'Wed'},
                              {'day': 4, 'label': 'Thu'},
                              {'day': 5, 'label': 'Fri'},
                              {'day': 6, 'label': 'Sat'},
                              {'day': 7, 'label': 'Sun'},
                            ].map((item) {
                              final day = item['day'] as int;
                              final label = item['label'] as String;
                              final isSelected = _repeatDays.contains(day);
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      if (_repeatDays.length > 1) {
                                        _repeatDays.remove(day);
                                      }
                                    } else {
                                      _repeatDays.add(day);
                                      _repeatDays.sort();
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 42,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.primaryColor
                                          : theme.colorScheme.outline.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
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

class CrossPriorityWidget extends ConsumerWidget {
  final Priority currentPriority;
  final ValueChanged<Priority> onChanged;

  const CrossPriorityWidget({
    super.key,
    required this.currentPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prioritiesAsync = ref.watch(prioritiesFutureProvider);
    final priorities = prioritiesAsync.maybeWhen(
      data: (list) => list.isNotEmpty ? list : Priority.defaultPriorities,
      orElse: () => Priority.defaultPriorities,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority Level',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: priorities.map((p) {
              final isSelected = p == currentPriority;
              final priorityColor = getPriorityColor(p, theme);
              final isUrgent = p.name.toLowerCase().contains('urgent') ||
                  p.name.toLowerCase().contains('critical');

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => onChanged(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? priorityColor.withValues(alpha: 0.18)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? priorityColor : theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUrgent)
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: isSelected ? priorityColor : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        Text(
                          p.name.toUpperCase(),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isSelected ? priorityColor : theme.textTheme.bodyLarge?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
