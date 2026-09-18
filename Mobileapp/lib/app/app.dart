import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/reminders/presentation/providers/reminder_list_provider.dart';
import '../core/services/notification_service.dart';

const List<Color> appAccentColors = [
  Color(0xFF6366F1), // Indigo (default)
  Color(0xFF10B981), // Emerald
  Color(0xFF8B5CF6), // Purple
  Color(0xFFF59E0B), // Amber
  Color(0xFFEF4444), // Red
];

class ReminderApp extends ConsumerStatefulWidget {
  const ReminderApp({super.key});

  @override
  ConsumerState<ReminderApp> createState() => _ReminderAppState();
}

class _ReminderAppState extends ConsumerState<ReminderApp> {
  Timer? _foregroundAlarmCheckTimer;
  final Set<String> _triggeredReminderIds = {};

  @override
  void initState() {
    super.initState();
    _startForegroundAlarmChecker();
  }

  void _startForegroundAlarmChecker() {
    _foregroundAlarmCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final reminders = ref.read(reminderListNotifierProvider).reminders;
      for (final r in reminders) {
        if (!r.isCompleted && (r.alarmEnabled || r.hasAlarm)) {
          final diff = now.difference(r.scheduledAt).inSeconds;
          if (diff >= 0 && diff <= 30 && !_triggeredReminderIds.contains(r.id)) {
            _triggeredReminderIds.add(r.id);
            NotificationService.onAlarmTriggered?.call(r.id);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _foregroundAlarmCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    
    Color primaryColor;
    if (settings.accentColorIndex == -1 && settings.customAccentColor != null) {
      primaryColor = Color(settings.customAccentColor!);
    } else {
      // Ensure index is within bounds
      final colorIndex = settings.accentColorIndex.clamp(0, appAccentColors.length - 1);
      primaryColor = appAccentColors[colorIndex];
    }

    return MaterialApp.router(
      title: 'Time Bell',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.getLightTheme(primaryColor),
      darkTheme: AppTheme.getDarkTheme(primaryColor),
      routerConfig: appRouter,
    );
  }
}
