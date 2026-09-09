import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../features/reminders/domain/entities/reminder.dart';
import '../../features/settings/providers/settings_provider.dart';


@pragma('vm:entry-point')
void notificationTapBackground(fln.NotificationResponse notificationResponse) {
  // Handle background actions (like Snooze/Dismiss)
  if (notificationResponse.actionId == 'dismiss') {
    // Just dismiss, Android removes the notification automatically
  } else if (notificationResponse.actionId == 'snooze') {
    final idStr = notificationResponse.payload;
    if (idStr != null) {
      // Background isolate rescheduling logic if needed
    }
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final fln.FlutterLocalNotificationsPlugin _localNotifications = fln.FlutterLocalNotificationsPlugin();

  static const MethodChannel _settingsChannel =
      MethodChannel('com.reminderapp.reminder_app/settings');

  NotificationService._init();

  Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();
    final timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    const fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const fln.InitializationSettings initializationSettings = fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (fln.NotificationResponse response) {
        // Handle notification click if needed
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Notification Channels for Android
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          'reminder_channel_v2',
          'Reminder Notifications',
          description: '5 minute reminder notifications',
          importance: fln.Importance.high,
        ),
      );

      // Main high-priority alarm channel configured with Alarm audio attributes
      await androidPlugin.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          'alarm_channel_v2',
          'Reminder Alarms',
          description: 'Exact time reminder alarms',
          importance: fln.Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          audioAttributesUsage: fln.AudioAttributesUsage.alarm,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          'pomodoro_channel',
          'Pomodoro',
          description: 'Pomodoro timer notifications',
          importance: fln.Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  /// Checks if notification permissions are already granted
  Future<bool> areNotificationsPermitted() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      return granted ?? false;
    }
    return false;
  }

  /// Checks if exact alarms are allowed on Android 12+ (API 31+)
  Future<bool> canScheduleExactAlarms() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _settingsChannel.invokeMethod<bool>('canScheduleExactAlarms');
        return result ?? true;
      } catch (e) {
        debugPrint('Error checking exact alarm permission: $e');
      }
    }
    return true;
  }

  /// Requests exact alarm permission (opens Android settings on Android 12+)
  Future<void> requestExactAlarmsPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod<bool>('requestExactAlarmsPermission');
      } catch (e) {
        debugPrint('Error requesting exact alarm permission: $e');
      }
    }
  }

  /// Checks if the app is exempted from battery optimizations
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _settingsChannel
            .invokeMethod<bool>('isIgnoringBatteryOptimizations');
        return result ?? true;
      } catch (e) {
        debugPrint('Error checking battery optimization: $e');
      }
    }
    return true;
  }

  /// Guides user to Android battery optimization settings
  Future<bool> openBatteryOptimizationSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _settingsChannel
            .invokeMethod<bool>('openBatteryOptimizationSettings');
        return result ?? false;
      } catch (e) {
        debugPrint('Error opening battery optimization settings: $e');
      }
    }
    return false;
  }

  /// Opens application details in Android Settings
  Future<bool> openAppDetailsSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _settingsChannel
            .invokeMethod<bool>('openAppDetailsSettings');
        return result ?? false;
      } catch (e) {
        debugPrint('Error opening app details settings: $e');
      }
    }
    return false;
  }

  Future<void> requestPermissions() async {
    // Request Android notification permissions
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    // Request iOS permissions
    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Determine schedule mode based on exact alarm permission
  Future<fln.AndroidScheduleMode> _determineScheduleMode() async {
    final canExact = await canScheduleExactAlarms();
    return canExact
        ? fln.AndroidScheduleMode.exactAllowWhileIdle
        : fln.AndroidScheduleMode.inexactAllowWhileIdle;
  }

  int _getNotificationId(String uuid) {
    int hash = 5381;
    for (int i = 0; i < uuid.length; i++) {
      hash = ((hash << 5) + hash) + uuid.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF;
    }
    return hash;
  }

  Future<void> scheduleNotification({
    required Reminder reminder,
  }) async {
    final notificationId = _getNotificationId(reminder.id);
    final tzScheduledDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    final scheduleMode = await _determineScheduleMode();

    // --------------------------------------------------------
    // 5 MINUTE WARNING
    // --------------------------------------------------------
    final fiveMinutesBefore = tzScheduledDate.subtract(const Duration(minutes: 5));

    try {
      if (reminder.warningEnabled && fiveMinutesBefore.isAfter(now)) {
        await _localNotifications.zonedSchedule(
          id: notificationId * 2,
          title: '⏰ Upcoming Reminder',
          body: '${reminder.title} starts in 5 minutes',
          scheduledDate: fiveMinutesBefore,
          notificationDetails: _getWarningNotificationDetails(reminder),
          androidScheduleMode: scheduleMode,
          payload: 'reminder_warning',
        );
      }

      // --------------------------------------------------------
      // EXACT TIME ALARM
      // --------------------------------------------------------
      if (reminder.alarmEnabled && tzScheduledDate.isAfter(now)) {
        final details = await _getAlarmNotificationDetails(reminder);
        await _localNotifications.zonedSchedule(
          id: notificationId * 2 + 1,
          title: '🚨 ${reminder.title}',
          body: reminder.description?.isNotEmpty == true
              ? reminder.description!
              : 'Alarm time reached for ${reminder.title}',
          scheduledDate: tzScheduledDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          payload: 'reminder_alarm',
        );
      }
    } catch (e) {
      debugPrint('Warning: Failed to schedule notification: $e');
    }
  }

  Future<void> scheduleRepeatingNotification({
    required Reminder reminder,
  }) async {
    final notificationId = _getNotificationId(reminder.id);
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);

    // Calculate future date if original scheduled date is in the past
    while (scheduledDate.isBefore(now)) {
      if (reminder.repeatType.name == 'daily') {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      } else if (reminder.repeatType.name == 'weekly') {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      } else if (reminder.repeatType.name == 'monthly') {
        scheduledDate = tz.TZDateTime(
          tz.local,
          scheduledDate.year,
          scheduledDate.month + 1,
          scheduledDate.day,
          scheduledDate.hour,
          scheduledDate.minute,
          scheduledDate.second,
        );
      } else {
        break;
      }
    }

    fln.DateTimeComponents? matchComponents;
    if (reminder.repeatType.name == 'daily') {
      matchComponents = fln.DateTimeComponents.time;
    } else if (reminder.repeatType.name == 'weekly') {
      matchComponents = fln.DateTimeComponents.dayOfWeekAndTime;
    } else if (reminder.repeatType.name == 'monthly') {
      matchComponents = fln.DateTimeComponents.dayOfMonthAndTime;
    }

    final scheduleMode = await _determineScheduleMode();

    try {
      if (reminder.alarmEnabled) {
        final details = await _getAlarmNotificationDetails(reminder);
        await _localNotifications.zonedSchedule(
          id: notificationId,
          title: '🚨 ${reminder.title}',
          body: reminder.description?.isNotEmpty == true
              ? reminder.description!
              : 'Recurring alarm for ${reminder.title}',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: matchComponents,
          payload: 'reminder_recurring',
        );
      }
    } catch (e) {
      debugPrint('Warning: Failed to schedule repeating notification: $e');
    }
  }

  /// Cancels any scheduled notification or alarm for the given reminder id
  Future<void> cancelNotification(String id) async {
    final notificationId = _getNotificationId(id);
    try {
      await _localNotifications.cancel(id: notificationId * 2);
      await _localNotifications.cancel(id: notificationId * 2 + 1);
      await _localNotifications.cancel(id: notificationId);
    } catch (e) {
      debugPrint('Warning: Failed to cancel notification: $e');
    }
  }

  /// Synchronize all stored reminders with native AlarmManager
  Future<void> rescheduleAllActiveReminders(List<Reminder> reminders) async {
    final now = DateTime.now();
    for (final reminder in reminders) {
      await cancelNotification(reminder.id);

      if (!reminder.isCompleted && reminder.alarmEnabled) {
        if (reminder.isRepeating && reminder.repeatType != RepeatType.none) {
          await scheduleRepeatingNotification(reminder: reminder);
        } else if (reminder.scheduledAt.isAfter(now)) {
          await scheduleNotification(reminder: reminder);
        }
      }
    }
  }

  fln.NotificationDetails _getWarningNotificationDetails(Reminder reminder) {
    return fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'reminder_channel_v2',
        'Reminder Notifications',
        channelDescription: '5 minute reminder notifications',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        playSound: reminder.alarmSoundEnabled,
        enableVibration: reminder.alarmVibrationEnabled,
      ),
      iOS: fln.DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: reminder.alarmSoundEnabled,
      ),
    );
  }

  Future<fln.NotificationDetails> _getAlarmNotificationDetails(Reminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final globalRingtone = prefs.getString('defaultRingtone') ?? 'morning_breeze';
    final ringtoneId = (reminder.ringtone != null && reminder.ringtone!.isNotEmpty)
        ? reminder.ringtone!
        : globalRingtone;
    
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
        
    String channelId = 'alarm_channel_v2';
    
    if (androidPlugin != null) {
      if (!reminder.alarmSoundEnabled) {
        channelId = 'alarm_channel_silent';
        await androidPlugin.createNotificationChannel(
          fln.AndroidNotificationChannel(
            channelId,
            'Silent Alarms',
            description: 'Alarms without sound',
            importance: fln.Importance.max,
            playSound: false,
            enableVibration: reminder.alarmVibrationEnabled,
            enableLights: true,
            audioAttributesUsage: fln.AudioAttributesUsage.alarm,
          ),
        );
      } else {
        final isBuiltIn = builtInRingtones.any((r) => r.id == ringtoneId);
        
        if (isBuiltIn) {
          channelId = 'alarm_channel_$ringtoneId';
          final ringtoneObj = builtInRingtones.firstWhere(
            (r) => r.id == ringtoneId,
            orElse: () => BuiltInRingtone(id: ringtoneId, name: ringtoneId),
          );
          await androidPlugin.createNotificationChannel(
            fln.AndroidNotificationChannel(
              channelId,
              'Alarm Sound (${ringtoneObj.name})',
              description: 'Exact time reminder alarm with ${ringtoneObj.name}',
              importance: fln.Importance.max,
              playSound: true,
              enableVibration: reminder.alarmVibrationEnabled,
              enableLights: true,
              audioAttributesUsage: fln.AudioAttributesUsage.alarm,
              sound: fln.RawResourceAndroidNotificationSound(ringtoneId),
            ),
          );
        } else {
          final customFile = File(ringtoneId);
          if (customFile.existsSync()) {
            final hash = ringtoneId.hashCode.abs();
            channelId = 'alarm_channel_custom_$hash';
            await androidPlugin.createNotificationChannel(
              fln.AndroidNotificationChannel(
                channelId,
                'Custom Alarm Sound',
                description: 'Exact time reminder alarm with custom sound',
                importance: fln.Importance.max,
                playSound: true,
                enableVibration: reminder.alarmVibrationEnabled,
                enableLights: true,
                audioAttributesUsage: fln.AudioAttributesUsage.alarm,
                sound: fln.UriAndroidNotificationSound('file://$ringtoneId'),
              ),
            );
          } else {
            // Fallback to default morning_breeze channel if custom file is missing
            channelId = 'alarm_channel_morning_breeze';
            await androidPlugin.createNotificationChannel(
              fln.AndroidNotificationChannel(
                channelId,
                'Alarm Sound (Morning Breeze)',
                description: 'Exact time reminder alarm with Morning Breeze sound',
                importance: fln.Importance.max,
                playSound: true,
                enableLights: true,
                audioAttributesUsage: fln.AudioAttributesUsage.alarm,
                sound: const fln.RawResourceAndroidNotificationSound('morning_breeze'),
              ),
            );
          }
        }
      }
    }

    return fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        channelId,
        'Reminder Alarms',
        channelDescription: 'Exact time reminder alarms',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        playSound: reminder.alarmSoundEnabled,
        enableVibration: reminder.alarmVibrationEnabled,
        category: fln.AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: fln.NotificationVisibility.public,
        audioAttributesUsage: fln.AudioAttributesUsage.alarm,
        ticker: 'Alarm: ${reminder.title}',
        actions: const <fln.AndroidNotificationAction>[
          fln.AndroidNotificationAction(
            'snooze',
            'SNOOZE',
            cancelNotification: true,
          ),
          fln.AndroidNotificationAction(
            'dismiss',
            'DISMISS',
            cancelNotification: true,
          ),
        ],
      ),
      iOS: fln.DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: reminder.alarmSoundEnabled,
        sound: ringtoneId.endsWith('.wav') || ringtoneId.endsWith('.mp3') ? ringtoneId : '$ringtoneId.mp3',
      ),
    );
  }


  Future<void> showPomodoroFinished() async {
    const details = fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro',
        channelDescription: 'Pomodoro timer',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: fln.DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: 9000,
      title: '🍅 Pomodoro Complete',
      body: 'Great job! Your focus session is finished.',
      notificationDetails: details,
    );
  }
}
