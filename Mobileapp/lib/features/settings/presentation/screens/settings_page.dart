import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:io';

import '../../../../app/theme/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../reminders/presentation/providers/reminder_list_provider.dart';
import '../../../reminders/domain/entities/reminder.dart';
import '../../../../core/services/notification_service.dart';
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
              'Customize your Time Bell experience',
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
              _SettingsTile(
                title: 'Share App',
                subtitle: 'Invite friends & family to use Time Bell',
                icon: Icons.share_rounded,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _shareApp(context),
                showDivider: false,
              ),
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
              ),
              _SettingsTile(
                title: 'Analytics & Insights',
                subtitle: 'Completion rates, focus trends, and streaks',
                icon: Icons.insights_rounded,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/statistics'),
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
                showDivider: true,
              ),
              _SettingsTile(
                title: 'Exact Alarms (Timely Alerts)',
                subtitle: 'Ensure alarms trigger at the exact minute',
                icon: Icons.alarm_on_outlined,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _checkAndRequestExactAlarmPermission(context),
                showDivider: true,
              ),
              _SettingsTile(
                title: 'Background & Battery Settings',
                subtitle: 'Prevent Android from putting alarms to sleep',
                icon: Icons.battery_charging_full_outlined,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showBatteryOptimizationDialog(context),
                showDivider: false,
              ),
            ],
          ),

          _SettingsSection(
            title: 'Notification & Alarm Tests',
            children: [
              _SettingsTile(
                title: 'Test Notification',
                subtitle: 'Trigger a sample push alert with sound',
                icon: Icons.notifications_active_rounded,
                trailing: const Icon(Icons.play_circle_outline_rounded),
                onTap: () async {
                  await NotificationService.instance.testNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification sent! Check your notification shade.')),
                    );
                  }
                },
              ),
              _SettingsTile(
                title: 'Test Advance Warning Alert',
                subtitle: 'Preview advance upcoming notification',
                icon: Icons.timer_outlined,
                trailing: const Icon(Icons.play_circle_outline_rounded),
                onTap: () async {
                  await NotificationService.instance.testAdvanceAlert();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Advance alert preview sent!')),
                    );
                  }
                },
              ),
              _SettingsTile(
                title: 'Test Vibration Pattern',
                subtitle: 'Trigger haptic vibration test',
                icon: Icons.vibration_rounded,
                trailing: const Icon(Icons.play_circle_outline_rounded),
                onTap: () async {
                  await NotificationService.instance.testVibration(settings.alarmVibrationEnabled ? 'strong' : 'medium');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vibration test triggered!')),
                    );
                  }
                },
              ),
              _SettingsTile(
                title: 'Preview Full-Screen Alarm Screen',
                subtitle: 'Test clock, audio loop, snooze & dismiss UI',
                icon: Icons.alarm_rounded,
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => context.push('/alarm/preview-test-alarm'),
                showDivider: false,
              ),
            ],
          ),

          _SettingsSection(
            title: 'Data & Storage',
            children: [
              _SettingsTile(
                title: 'Export Backup (JSON)',
                subtitle: 'Save or share all reminders to a JSON file',
                icon: Icons.file_download_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _exportData(context, ref),
              ),
              _SettingsTile(
                title: 'Import Backup (JSON)',
                subtitle: 'Restore reminders from a JSON file or text',
                icon: Icons.file_upload_outlined,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _importData(context, ref),
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
            title: 'Server & Synchronization',
            children: [
              _SettingsTile(
                title: 'Sync Now',
                subtitle: 'Pull latest reminders from admin panel',
                icon: Icons.sync_rounded,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                showDivider: false,
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Syncing with admin panel...'), duration: Duration(seconds: 1)),
                  );
                  await ref.read(reminderListNotifierProvider.notifier).syncWithServer();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync complete!')),
                    );
                  }
                },
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
                title: 'Share App',
                subtitle: 'Invite friends & family to use Time Bell',
                icon: Icons.share_rounded,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _shareApp(context),
                showDivider: true,
              ),
              _SettingsTile(
                title: 'Rate Time Bell',
                subtitle: 'Leave a review on Google Play',
                icon: Icons.star_rate_rounded,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _openPlayStoreRating(context),
                showDivider: true,
              ),
              _SettingsTile(
                title: 'Privacy Policy',
                subtitle: 'Learn how Time Bell handles your data',
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

  Future<void> _shareApp(BuildContext context) async {
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.reminderapp.reminder_app';
    const shareMessage = 'Try Timebell – a simple reminder and alarm app.\n\n$playStoreUrl';

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await SharePlus.instance.share(
        ShareParams(
          text: shareMessage,
          subject: 'Timebell - Reminder & Alarm App',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Error launching share sheet: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open share dialog. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _checkAndRequestExactAlarmPermission(BuildContext context) async {
    final canExact = await NotificationService.instance.canScheduleExactAlarms();
    if (canExact) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exact alarms are already enabled! Alarms will trigger precisely on time.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exact Alarm Permission Required'),
            content: const Text(
              'Android requires explicit permission for alarms to fire at exact scheduled times when the app is closed.\n\n'
              'Please allow "Alarms & Reminders" in the next screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await NotificationService.instance.requestExactAlarmsPermission();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showBatteryOptimizationDialog(BuildContext context) async {
    final isIgnored = await NotificationService.instance.isIgnoringBatteryOptimizations();
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isIgnored ? Icons.check_circle_outline : Icons.battery_alert_outlined,
                color: isIgnored ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Background Alarms')),
            ],
          ),
          content: Text(
            isIgnored
                ? 'Battery optimization is already disabled for Time Bell. Your alarms will trigger reliably when the app is closed, minimized, or in the background.\n\nNote: If you manually Force Stop the app from Android Settings, Android disables all background tasks until the app is opened again.'
                : 'To ensure alarms ring reliably when Time Bell is closed, minimized, or when the screen is locked, allow Time Bell to run in the background without battery restrictions.\n\n'
                  'Recommended settings in Android:\n'
                  '• App Battery Usage: "Unrestricted" or "Don\'t optimize"\n'
                  '• Auto-start / Background Activity: Enabled\n\n'
                  'Note: Android Force-Stop puts the app in a stopped state until reopened.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final opened = await NotificationService.instance.openBatteryOptimizationSettings();
                if (!opened) {
                  await NotificationService.instance.openAppDetailsSettings();
                }
              },
              child: const Text('Change Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openPlayStoreRating(BuildContext context) async {
    const packageName = 'com.reminderapp.reminder_app';
    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Play Store.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open rating page: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatRingtoneName(String ringtoneId) {
    return formatRingtoneName(ringtoneId);
  }


  Widget _buildProfileCard(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1E1B4B), // Deep Indigo / Purple
                  const Color(0xFF312E81),
                  const Color(0xFF2E1065),
                ]
              : [
                  const Color(0xFFEEF2FF),
                  const Color(0xFFE0E7FF),
                  const Color(0xFFEDE9FE),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: isDarkMode ? 0.35 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDarkMode ? 0.25 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1), // Primary Indigo
                  Color(0xFF818CF8), // Purple
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Container(
                color: const Color(0xFF0F172A),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF6366F1),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Time Bell',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1E1B4B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: isDarkMode ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'v1.0.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your personal productivity assistant',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF4338CA).withValues(alpha: 0.85),
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
        content: RadioGroup<int>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mins) {
              return RadioListTile<int>(
                title: Text('$mins minutes'),
                value: mins,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
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
        'repeatDays': r.repeatDays,
        'hasAlarm': r.hasAlarm,
        'warningEnabled': r.warningEnabled,
        'alarmEnabled': r.alarmEnabled,
        'alarmSoundEnabled': r.alarmSoundEnabled,
        'alarmVibrationEnabled': r.alarmVibrationEnabled,
        'snoozeMinutes': r.snoozeMinutes,
        'ringtone': r.ringtone,
        'advanceMinutes': r.advanceMinutes,
        'vibrationPattern': r.vibrationPattern,
        'createdAt': r.createdAt.toIso8601String(),
      }).toList();

      final backupData = {
        'app': 'Timebell',
        'exported_at': DateTime.now().toIso8601String(),
        'total_reminders': reminders.length,
        'reminders': jsonList,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/timebell_backup_$timestamp.json');
      await file.writeAsString(jsonString);

      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Timebell Backup ($timestamp)',
          text: 'Timebell Reminders Backup ($timestamp.json)',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  void _importData(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImportBackupSheet(ref: ref),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
        activeThumbColor: Theme.of(context).colorScheme.primary,
      ),
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
              'Time Bell is a reminder and productivity application designed to help you organize your daily tasks. We respect your privacy and are committed to protecting it through our compliance with this policy.',
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
              '4. Data Storage & Security',
              'By default, Time Bell operates completely offline. All reminders and preferences are stored locally on your device in a secure SQLite database. We do not transmit your data to external servers or cloud services unless you explicitly configure an optional self-hosted server synchronization URL under Settings.',
            ),
            _buildSection(
              theme,
              '5. Notifications',
              'Time Bell requires notification permissions to alert you about scheduled reminders. These notifications are generated locally on your device and are not pushed from a remote server.',
            ),
            _buildSection(
              theme,
              '6. Third-Party Services & Analytics',
              'Time Bell does not integrate any third-party tracking, advertising, analytics SDKs, or Firebase services. We do not sell, rent, monetize, or transmit your personal information.',
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

class _ImportBackupSheet extends StatefulWidget {
  final WidgetRef ref;

  const _ImportBackupSheet({required this.ref});

  @override
  State<_ImportBackupSheet> createState() => _ImportBackupSheetState();
}

class _ImportBackupSheetState extends State<_ImportBackupSheet> {
  final TextEditingController _pasteController = TextEditingController();
  bool _isLoading = false;

  Future<void> _processJsonString(String jsonStr) async {
    setState(() => _isLoading = true);
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      List<dynamic> list;
      if (decoded is Map && decoded['reminders'] is List) {
        list = decoded['reminders'];
      } else if (decoded is List) {
        list = decoded;
      } else {
        throw Exception('Invalid Timebell backup JSON structure.');
      }

      int imported = 0;
      final notifier = widget.ref.read(reminderListNotifierProvider.notifier);
      for (final item in list) {
        if (item is Map) {
          try {
            final map = Map<String, dynamic>.from(item);
            final reminder = Reminder(
              id: map['id']?.toString() ?? const Uuid().v4(),
              title: map['title']?.toString() ?? 'Restored Reminder',
              description: map['description']?.toString(),
              scheduledAt: map['scheduledAt'] != null
                  ? DateTime.parse(map['scheduledAt'])
                  : (map['scheduled_at'] != null ? DateTime.parse(map['scheduled_at']) : DateTime.now().add(const Duration(hours: 1))),
              endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
              categoryId: map['categoryId']?.toString() ?? map['category_id']?.toString() ?? '1',
              priority: Priority.fromString(map['priority']?.toString()),
              isCompleted: map['isCompleted'] == true || map['is_completed'] == 1,
              isRepeating: map['isRepeating'] == true || map['is_repeating'] == 1,
              repeatType: map['repeatType'] != null
                  ? RepeatType.values.firstWhere(
                      (r) => r.name.toLowerCase() == map['repeatType'].toString().toLowerCase(),
                      orElse: () => RepeatType.none,
                    )
                  : RepeatType.none,
              repeatDays: map['repeatDays'] is List ? List<int>.from(map['repeatDays']) : null,
              hasAlarm: map['hasAlarm'] != false,
              warningEnabled: map['warningEnabled'] != false,
              alarmEnabled: map['alarmEnabled'] == true,
              alarmSoundEnabled: map['alarmSoundEnabled'] != false,
              alarmVibrationEnabled: map['alarmVibrationEnabled'] != false,
              snoozeMinutes: (map['snoozeMinutes'] as num?)?.toInt() ?? 5,
              ringtone: map['ringtone']?.toString(),
              advanceMinutes: (map['advanceMinutes'] as num?)?.toInt() ?? 5,
              vibrationPattern: map['vibrationPattern']?.toString() ?? 'medium',
              createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
            );

            await notifier.saveReminder(reminder);
            imported++;
          } catch (itemErr) {
            debugPrint('Error restoring item: $itemErr');
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored $imported reminders!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickJsonFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final content = await file.readAsString();
        await _processJsonString(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.file_upload_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text('Restore Reminders (JSON)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickJsonFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Pick JSON Backup File'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('OR PASTE JSON', style: theme.textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pasteController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Paste raw JSON backup content here...',
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        final text = _pasteController.text.trim();
                        if (text.isNotEmpty) {
                          _processJsonString(text);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Restore from Pasted Text', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
