import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/reminder.dart';
import '../providers/reminder_list_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/utils/ui_helpers.dart';
import '../../../../core/utils/permission_helper.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QuickAddSheet(),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  String? _selectedCategoryId;
  bool _alarmEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      final categoriesAsync = ref.read(categoriesFutureProvider);
      categoriesAsync.whenData((categories) {
        if (categories.isNotEmpty && _selectedCategoryId == null && mounted) {
          setState(() {
            _selectedCategoryId = categories.first.id;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setQuickTime(Duration offset, {int? setHour, int? setMinute}) {
    final now = DateTime.now();
    DateTime target = now.add(offset);
    if (setHour != null) {
      target = DateTime(target.year, target.month, target.day, setHour, setMinute ?? 0);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
    }
    setState(() {
      _selectedDate = target;
      _selectedTime = TimeOfDay(hour: target.hour, minute: target.minute);
    });
  }

  Future<void> _pickCustomDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final scheduled = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final categories = ref.read(categoriesFutureProvider).asData?.value ?? [];
    final categoryId = _selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : 'general');
    final settings = ref.read(settingsNotifierProvider);

    await PermissionHelper.requestNotificationPermissionWithConsent(context);
    if (!mounted) return;

    final reminder = Reminder(
      id: const Uuid().v4(),
      title: title,
      scheduledAt: scheduled,
      categoryId: categoryId,
      priority: Priority.medium,
      isCompleted: false,
      isRepeating: false,
      repeatType: RepeatType.none,
      advanceMinutes: settings.fiveMinuteWarningEnabled ? 5 : 0,
      vibrationPattern: settings.alarmVibrationEnabled ? 'medium' : 'off',
      hasAlarm: _alarmEnabled,
      warningEnabled: settings.fiveMinuteWarningEnabled,
      alarmEnabled: _alarmEnabled,
      alarmSoundEnabled: settings.alarmSoundEnabled,
      alarmVibrationEnabled: settings.alarmVibrationEnabled,
      snoozeMinutes: settings.defaultSnoozeDuration,
      ringtone: settings.defaultRingtone,
      createdAt: DateTime.now(),
    );

    await ref.read(reminderListNotifierProvider.notifier).saveReminder(reminder);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder "$title" added!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesFutureProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final timeStr = DateFormat.jm().format(
      DateTime(2026, 1, 1, _selectedTime.hour, _selectedTime.minute),
    );
    final dateStr = DateFormat.MMMd().format(_selectedDate);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title row
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Add Reminder',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick input field
                TextField(
                  controller: _titleController,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Call dentist, Team standup...',
                    hintStyle: TextStyle(color: theme.hintColor),
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick time suggestion chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.flash_on_rounded, size: 14),
                        label: const Text('+1 Hour'),
                        onPressed: () => _setQuickTime(const Duration(hours: 1)),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.nightlight_round, size: 14),
                        label: const Text('Tonight (8 PM)'),
                        onPressed: () => _setQuickTime(Duration.zero, setHour: 20),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.wb_sunny_rounded, size: 14),
                        label: const Text('Tomorrow 9 AM'),
                        onPressed: () => _setQuickTime(const Duration(days: 1), setHour: 9),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.edit_calendar_rounded, size: 14),
                        label: Text('$dateStr, $timeStr'),
                        onPressed: _pickCustomDateTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Categories Row
                categoriesAsync.maybeWhen(
                  data: (categories) {
                    if (categories.isEmpty) return const SizedBox.shrink();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id;
                          final color = parseHexColor(cat.color);
                          final icon = getCategoryIcon(cat.icon);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                              label: Text(cat.name),
                              selected: isSelected,
                              selectedColor: color,
                              onSelected: (val) {
                                if (val) setState(() => _selectedCategoryId = cat.id);
                              },
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // Alarm switch & Submit Button row
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _alarmEnabled = !_alarmEnabled),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _alarmEnabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                              color: _alarmEnabled ? Colors.orange : theme.disabledColor,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _alarmEnabled ? 'Alarm ON' : 'Silent',
                              style: TextStyle(
                                color: _alarmEnabled ? Colors.orange : theme.disabledColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submit,
                      child: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
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
}
