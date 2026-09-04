import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'dart:convert';
import '../../../../app/theme/theme_provider.dart';
import '../../../../app/app.dart';
import '../../providers/settings_provider.dart';
import '../../../reminders/presentation/providers/reminder_list_provider.dart';

import 'package:path/path.dart' as p;
import 'ringtone_selection_screen.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeNotifierProvider) == ThemeMode.dark;
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Customize your FocusDay experience',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildProfileCard(theme, isDarkMode),
          
          _SettingsSection(
            title: 'Appearance',
            children: [
              _SettingsSwitch(
                title: 'Dark Mode',
                icon: isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                value: isDarkMode,
                onChanged: (val) => ref.read(themeNotifierProvider.notifier).toggleTheme(),
              ),
              _SettingsSwitch(
                title: 'Use 24-Hour Format',
                subtitle: 'e.g. 14:30 instead of 2:30 PM',
                icon: Icons.access_time,
                value: settings.use24HourFormat,
                onChanged: (val) => ref.read(settingsNotifierProvider.notifier).setUse24HourFormat(val),
              ),
              const _SettingsTile(
                title: 'Theme Color',
                subtitle: 'Personalize your accent color',
                icon: Icons.palette_outlined,
                showDivider: false,
                trailing: SizedBox.shrink(),
              ),
              const _AccentColorPicker(),
            ],
          ),

          _SettingsSection(
            title: 'Productivity',
            children: [
              _SettingsTile(
                title: 'Work Duration',
                subtitle: '${settings.workDuration} minutes',
                icon: Icons.timer_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDurationDialog(context, ref, 'workDuration', settings.workDuration, [15, 25, 30, 45, 50, 60]),
              ),
              _SettingsTile(
                title: 'Short Break Duration',
                subtitle: '${settings.shortBreakDuration} minutes',
                icon: Icons.coffee_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDurationDialog(context, ref, 'shortBreakDuration', settings.shortBreakDuration, [5, 10, 15]),
              ),
              _SettingsTile(
                title: 'Long Break Duration',
                subtitle: '${settings.longBreakDuration} minutes',
                icon: Icons.weekend_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDurationDialog(context, ref, 'longBreakDuration', settings.longBreakDuration, [15, 20, 30]),
                showDivider: false,
              ),
            ],
          ),

          _SettingsSection(
            title: 'Calendar & Time',
            children: [
              _SettingsSwitch(
                title: 'Start Week on Monday',
                subtitle: settings.startOfWeekMonday ? 'Week starts on Monday' : 'Week starts on Sunday',
                icon: Icons.calendar_today_outlined,
                value: settings.startOfWeekMonday,
                onChanged: (val) => ref.read(settingsNotifierProvider.notifier).setStartOfWeekMonday(val),
                showDivider: false,
              ),
            ],
          ),

          _SettingsSection(
            title: 'Alarm & Notifications',
            children: [
              _SettingsSwitch(
                title: 'Enable Notifications',
                subtitle: 'Allow app to send notifications',
                icon: Icons.notifications_active_outlined,
                value: settings.notificationsEnabled,
                onChanged: (val) => ref.read(settingsNotifierProvider.notifier).setNotificationsEnabled(val),
              ),
              _SettingsSwitch(
                title: '5-Minute Warning',
                subtitle: 'Notify 5 minutes before scheduled time',
                icon: Icons.timer_outlined,
                value: settings.fiveMinuteWarningEnabled,
                onChanged: (val) => ref.read(settingsNotifierProvider.notifier).setFiveMinuteWarningEnabled(val),
              ),
              _SettingsSwitch(
                title: 'Alarm Sound',
                subtitle: 'Play sound when alarm triggers',
                icon: Icons.volume_up_outlined,
                value: settings.alarmSoundEnabled,
                onChanged: (val) => ref.read(settingsNotifierProvider.notifier).setAlarmSoundEnabled(val),
              ),
              _SettingsTile(
                title: 'Ringtone',
                subtitle: _formatRingtoneName(settings.defaultRingtone),
                icon: Icons.music_note_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RingtoneSelectionScreen(),
                    ),
                  );
                },
              ),
              _SettingsSwitch(
                title: 'Alarm Vibration',
                subtitle: 'Vibrate when alarm triggers',
                icon: Icons.vibration,
                value: settings.alarmVibrationEnabled,
                onChanged: (val) => ref.read(settingsNotifierProvider.notifier).setAlarmVibrationEnabled(val),
              ),
              _SettingsTile(
                title: 'Default Snooze Duration',
                subtitle: '${settings.defaultSnoozeDuration} minutes',
                icon: Icons.snooze_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSnoozeDurationDialog(context, ref, settings.defaultSnoozeDuration),
                showDivider: false,
              ),
            ],
          ),

          _SettingsSection(
            title: 'Data & Storage',
            children: [
              _SettingsTile(
                title: 'Export Data',
                subtitle: 'Backup reminders to JSON',
                icon: Icons.file_download_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _exportData(context, ref),
              ),
              _SettingsTile(
                title: 'Clear Completed Tasks',
                subtitle: 'Remove all checked-off reminders',
                icon: Icons.clear_all,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showClearCompletedDialog(context, ref),
              ),
              _SettingsTile(
                title: 'Delete All Data',
                subtitle: 'Irreversibly delete all reminders',
                icon: Icons.delete_outline,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDeleteAllDialog(context, ref),
                showDivider: false,
              ),
            ],
          ),

          _SettingsSection(
            title: 'About & Legal',
            children: [
              ref.watch(packageInfoProvider).when(
                data: (info) => _SettingsTile(
                  title: 'Version',
                  subtitle: '${info.appName} v${info.version}+${info.buildNumber}',
                  icon: Icons.info_outline,
                  trailing: const SizedBox.shrink(),
                  showDivider: true,
                ),
                loading: () => const _SettingsTile(
                  title: 'Version',
                  subtitle: 'Loading...',
                  icon: Icons.info_outline,
                  trailing: SizedBox.shrink(),
                  showDivider: true,
                ),
                error: (error, stackTrace) => const _SettingsTile(
                  title: 'Version',
                  subtitle: 'Unknown',
                  icon: Icons.info_outline,
                  trailing: SizedBox.shrink(),
                  showDivider: true,
                ),
              ),
              _SettingsTile(
                title: 'Privacy Policy',
                subtitle: 'Learn how FocusDay handles your data',
                icon: Icons.privacy_tip_outlined,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRingtoneName(String ringtoneId) {
    if (ringtoneId == 'morning_alarm') return 'Morning Alarm';
    if (ringtoneId == 'classic_alarm') return 'Classic Alarm';
    if (ringtoneId == 'digital_alarm') return 'Digital Alarm';
    if (ringtoneId == 'gentle_alarm') return 'Gentle Alarm';
    return p.basename(ringtoneId);
  }

  Widget _buildProfileCard(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FocusDay',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? theme.colorScheme.onSurface : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your personal productivity assistant',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnoozeDurationDialog(BuildContext context, WidgetRef ref, int current) {
    _showDurationDialog(context, ref, 'snooze', current, [5, 10, 15, 30]);
  }

  void _showDurationDialog(BuildContext context, WidgetRef ref, String type, int current, List<int> options) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((mins) {
            return RadioListTile<int>(
              title: Text('$mins minutes'),
              value: mins,
              groupValue: current,
              onChanged: (val) {
                if (val != null) {
                  final notifier = ref.read(settingsNotifierProvider.notifier);
                  switch (type) {
                    case 'snooze':
                      notifier.setDefaultSnoozeDuration(val);
                      break;
                    case 'workDuration':
                      notifier.setWorkDuration(val);
                      break;
                    case 'shortBreakDuration':
                      notifier.setShortBreakDuration(val);
                      break;
                    case 'longBreakDuration':
                      notifier.setLongBreakDuration(val);
                      break;
                  }
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _exportData(BuildContext context, WidgetRef ref) {
    final reminders = ref.read(reminderListNotifierProvider).reminders;
    final jsonList = reminders.map((r) => {
      'id': r.id,
      'title': r.title,
      'description': r.description,
      'scheduledAt': r.scheduledAt.toIso8601String(),
      'endTime': r.endTime?.toIso8601String(),
      'categoryId': r.categoryId,
      'priority': r.priority.name,
      'isCompleted': r.isCompleted,
      'isRepeating': r.isRepeating,
      'repeatType': r.repeatType.name,
      'hasAlarm': r.hasAlarm,
      'createdAt': r.createdAt.toIso8601String(),
    }).toList();
    final jsonString = jsonEncode(jsonList);
    debugPrint('Exported JSON: $jsonString');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data exported successfully! (Simulated)')),
    );
  }

  void _showClearCompletedDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Completed Tasks?'),
        content: const Text('This will permanently delete all tasks that are currently marked as complete. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              final provider = ref.read(reminderListNotifierProvider.notifier);
              final reminders = ref.read(reminderListNotifierProvider).reminders;
              for (var r in reminders) {
                if (r.isCompleted) {
                  provider.deleteReminder(r.id);
                }
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completed tasks cleared.')));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?', style: TextStyle(color: Colors.red)),
        content: const Text('Are you absolutely sure you want to delete ALL reminders? This action is permanent and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              final provider = ref.read(reminderListNotifierProvider.notifier);
              final reminders = ref.read(reminderListNotifierProvider).reminders;
              for (var r in reminders) {
                provider.deleteReminder(r.id);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data deleted.')));
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isDarkMode ? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)) : null,
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                trailing,
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              indent: 56,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _SettingsSwitch({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showDivider: showDivider,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _AccentColorPicker extends ConsumerWidget {
  const _AccentColorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final selectedIndex = settings.accentColorIndex;
    final customAccentColor = settings.customAccentColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...List.generate(appAccentColors.length, (index) {
              final color = appAccentColors[index];
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () => ref.read(settingsNotifierProvider.notifier).setAccentColorIndex(index),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }),
            // Custom Color Button
            GestureDetector(
              onTap: () {
                _showColorPicker(context, ref, customAccentColor ?? appAccentColors[0].value);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selectedIndex == -1 && customAccentColor != null ? Color(customAccentColor) : theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedIndex == -1 ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                    width: 2,
                  ),
                  boxShadow: selectedIndex == -1 && customAccentColor != null
                      ? [
                          BoxShadow(
                            color: Color(customAccentColor).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selectedIndex == -1 ? Icons.check : Icons.add,
                  color: selectedIndex == -1 ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, int currentColorValue) {
    Color pickerColor = Color(currentColorValue);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Select'),
              onPressed: () {
                ref.read(settingsNotifierProvider.notifier).setCustomAccentColor(pickerColor.value);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            
            _buildSection(
              theme,
              '1. Introduction',
              'FocusDay is a reminder and productivity application designed to help you organize your daily tasks. We respect your privacy and are committed to protecting it through our compliance with this policy.',
            ),
            _buildSection(
              theme,
              '2. Information We Collect',
              'We collect and store information strictly related to your usage of the app, including:\n'
              '• Reminders and tasks created by the user\n'
              '• Reminder dates, times, and categories\n'
              '• App preferences and settings',
            ),
            _buildSection(
              theme,
              '3. How We Use Information',
              'The information collected is used solely to provide the app\'s core functionality:\n'
              '• To create and manage your reminders\n'
              '• To schedule local notifications and alarms\n'
              '• To save and apply your user preferences',
            ),
            _buildSection(
              theme,
              '4. Data Storage',
              'All data collected by FocusDay is stored locally on your device. We do not use cloud storage, nor do we transmit your reminders or tasks to external servers.',
            ),
            _buildSection(
              theme,
              '5. Notifications',
              'FocusDay requires notification permissions to alert you about scheduled reminders. These notifications are generated locally on your device and are not pushed from a remote server.',
            ),
            _buildSection(
              theme,
              '6. Third-Party Services',
              'We only use essential local packages for scheduling and routing. We do not use third-party analytics, advertising, tracking services, or Firebase.',
            ),
            _buildSection(
              theme,
              '7. Data Sharing',
              'Your data is never shared, sold, or rented to any third parties under any circumstances. It remains entirely on your local device.',
            ),
            _buildSection(
              theme,
              '8. Data Security',
              'Because your data is stored locally, its security depends on the physical security of your device and its operating system locks (e.g., PIN, fingerprint). We recommend maintaining secure device practices.',
            ),
            _buildSection(
              theme,
              '9. Children\'s Privacy',
              'Our application does not knowingly collect any data from children. As a locally-run productivity tool, it is safe for users of all ages.',
            ),
            _buildSection(
              theme,
              '10. Changes to This Privacy Policy',
              'We may update this privacy policy from time to time. Any changes will be reflected in future app updates with an updated "Last updated" date.',
            ),
            _buildSection(
              theme,
              '11. Contact Us',
              'If you have any questions or concerns regarding this privacy policy, please contact us through the app\'s support channels.',
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontSize: 14.5,
              color: theme.brightness == Brightness.dark 
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.9)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
