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

  /// Callback triggered when an alarm notification or full-screen intent is opened
  static void Function(String reminderId)? onAlarmTriggered;

  NotificationService._init();

  Future<void> init() async {
    // Initialize timezone with safe fallback
    tz.initializeTimeZones();
    try {
      final timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Warning: Timezone initialization failed, falling back: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

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
        final payload = response.payload;
        if (payload != null) {
          if (payload.startsWith('reminder_alarm:')) {
            final id = payload.substring('reminder_alarm:'.length);
            onAlarmTriggered?.call(id);
          } else if (payload.startsWith('reminder_recurring:')) {
            final id = payload.substring('reminder_recurring:'.length);
            onAlarmTriggered?.call(id);
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Listen for native Android AlarmManager triggers that wake the device
    _settingsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmTriggered') {
        final id = call.arguments as String?;
        if (id != null && id.isNotEmpty) {
          onAlarmTriggered?.call(id);
        }
      }
    });

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
          'alarm_channel_v5_morning_breeze',
          'Reminder Alarms (Default)',
          description: 'Exact time reminder alarms',
          importance: fln.Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          audioAttributesUsage: fln.AudioAttributesUsage.alarm,
          sound: fln.RawResourceAndroidNotificationSound('morning_breeze'),
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

  /// Checks if the app was cold-launched by an alarm notification or native AlarmClock intent
  Future<String?> getLaunchAlarmReminderId() async {
    // 1. Check native Android Intent directly
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final nativeId = await _settingsChannel.invokeMethod<String>('getInitialAlarmReminderId');
        if (nativeId != null && nativeId.isNotEmpty) {
          debugPrint('Detected cold start from native AlarmClock intent: $nativeId');
          return nativeId;
        }
      } catch (e) {
        debugPrint('Error reading native launch alarm ID: $e');
      }
    }

    // 2. Fallback to notification launch details
    try {
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final response = launchDetails.notificationResponse;
        if (response != null && (response.actionId == null || response.actionId!.isEmpty)) {
          final payload = response.payload;
          if (payload != null) {
            if (payload.startsWith('reminder_alarm:')) {
              return payload.substring('reminder_alarm:'.length);
            } else if (payload.startsWith('reminder_recurring:')) {
              return payload.substring('reminder_recurring:'.length);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading notification launch details: $e');
    }
    return null;
  }

  /// Schedules an OS-level AlarmManager.AlarmClock that physically powers on the screen
  /// and launches the full-screen alarm directly over the lockscreen.
  Future<void> scheduleNativeAlarm({
    required String reminderId,
    required int triggerAtMillis,
    required String title,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod('scheduleNativeAlarm', {
          'reminderId': reminderId,
          'triggerAtMillis': triggerAtMillis,
          'title': title,
        });
      } catch (e) {
        debugPrint('Error scheduling native AlarmClock: $e');
      }
    }
  }

  /// Cancels an OS-level AlarmManager.AlarmClock
  Future<void> cancelNativeAlarm(String reminderId) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod('cancelNativeAlarm', {
          'reminderId': reminderId,
        });
      } catch (e) {
        debugPrint('Error cancelling native AlarmClock: $e');
      }
    }
  }

  /// Powers on the display and sets keep-screen-on flags on Android
  Future<void> wakeUpScreen() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod('wakeUpScreen');
      } catch (e) {
        debugPrint('Error invoking wakeUpScreen: $e');
      }
    }
  }

  /// Releases wake locks and clears keep-screen-on flags
  Future<void> dismissAlarmFlags() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod('clearKeepScreenOn');
      } catch (e) {
        debugPrint('Error invoking clearKeepScreenOn: $e');
      }
    }
  }

  /// Checks if full-screen intents are allowed on Android 14+ (API 34+)
  Future<bool> canUseFullScreenIntent() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _settingsChannel.invokeMethod<bool>('canUseFullScreenIntent');
        return result ?? true;
      } catch (e) {
        debugPrint('Error checking full-screen intent permission: $e');
      }
    }
    return true;
  }

  /// Requests full-screen intent permission on Android 14+ (API 34+)
  Future<void> requestFullScreenIntentPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _settingsChannel.invokeMethod('requestFullScreenIntentPermission');
      } catch (e) {
        debugPrint('Error requesting full-screen intent permission: $e');
      }
    }
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
  Future<fln.AndroidScheduleMode> _determineScheduleMode({bool isAlarm = false}) async {
    final canExact = await canScheduleExactAlarms();
    if (!canExact) {
      return fln.AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return isAlarm
        ? fln.AndroidScheduleMode.alarmClock
        : fln.AndroidScheduleMode.exactAllowWhileIdle;
  }

  Int64List? _getVibrationPattern(String? pattern) {
    if (pattern == null || pattern == 'medium') {
      return Int64List.fromList([0, 500, 500, 500]);
    }
    switch (pattern) {
      case 'off':
        return null;
      case 'short':
        return Int64List.fromList([0, 200, 200, 200]);
      case 'medium':
        return Int64List.fromList([0, 500, 500, 500]);
      case 'long':
        return Int64List.fromList([0, 1000, 500, 1000]);
      case 'strong':
        return Int64List.fromList([0, 800, 200, 800, 200, 800, 200, 800]);
      default:
        return Int64List.fromList([0, 500, 500, 500]);
    }
  }

  int _getNotificationId(String uuid) {
    int hash = 5381;
    for (int i = 0; i < uuid.length; i++) {
      hash = ((hash << 5) + hash) + uuid.codeUnitAt(i);
      // Mask to 26 bits (0x03FFFFFF) so that notificationId * 16 + 15
      // stays well within signed 32-bit Integer.MAX_VALUE (2,147,483,647).
      hash = hash & 0x03FFFFFF;
    }
    return hash;
  }

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleNotification({
    required Reminder reminder,
  }) async {
    final notificationId = _getNotificationId(reminder.id);
    final tzScheduledDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    final exactAlarmScheduleMode = await _determineScheduleMode(isAlarm: true);
    final warningScheduleMode = await _determineScheduleMode(isAlarm: false);

    // --------------------------------------------------------
    // ADVANCE WARNING NOTIFICATION (OFF, 5m, 10m, 15m, 30m)
    // --------------------------------------------------------
    final advanceMinutes = reminder.advanceMinutes;
    try {
      if (reminder.warningEnabled && advanceMinutes > 0) {
        final advanceTime = tzScheduledDate.subtract(Duration(minutes: advanceMinutes));
        if (advanceTime.isAfter(now)) {
          final warningPayload = 'reminder_warning:${reminder.id}';
          final warningDetails = _getWarningNotificationDetails(reminder);
          final warningTitle = '⏰ Upcoming Reminder';
          final warningBody = '${reminder.title} starts in $advanceMinutes minutes';
          try {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16,
              title: warningTitle,
              body: warningBody,
              scheduledDate: advanceTime,
              notificationDetails: warningDetails,
              androidScheduleMode: warningScheduleMode,
              payload: warningPayload,
            );
          } catch (e) {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16,
              title: warningTitle,
              body: warningBody,
              scheduledDate: advanceTime,
              notificationDetails: warningDetails,
              androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
              payload: warningPayload,
            );
          }
        } else if (tzScheduledDate.isAfter(now) && tzScheduledDate.difference(now).inSeconds > 10) {
          final minsLeft = tzScheduledDate.difference(now).inMinutes;
          final warningPayload = 'reminder_warning:${reminder.id}';
          final warningDetails = _getWarningNotificationDetails(reminder);
          final warningTitle = '⏰ Upcoming Reminder';
          final warningBody = minsLeft <= 1
              ? '${reminder.title} starts very soon'
              : '${reminder.title} starts in $minsLeft minutes';
          try {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16,
              title: warningTitle,
              body: warningBody,
              scheduledDate: now.add(const Duration(seconds: 2)),
              notificationDetails: warningDetails,
              androidScheduleMode: warningScheduleMode,
              payload: warningPayload,
            );
          } catch (e) {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16,
              title: warningTitle,
              body: warningBody,
              scheduledDate: now.add(const Duration(seconds: 2)),
              notificationDetails: warningDetails,
              androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
              payload: warningPayload,
            );
          }
        }
      }

      // --------------------------------------------------------
      // EXACT TIME ALARM
      // --------------------------------------------------------
      if (reminder.alarmEnabled || reminder.hasAlarm) {
        var targetAlarmTime = tzScheduledDate;
        if (targetAlarmTime.isBefore(now)) {
          // If scheduled within the current minute (e.g. within last 60 seconds),
          // adjust to fire in 8 seconds so it doesn't get dropped!
          if (now.difference(targetAlarmTime).inSeconds < 60) {
            targetAlarmTime = now.add(const Duration(seconds: 8));
          }
        } else if (targetAlarmTime.difference(now).inSeconds < 4) {
          // Buffer tiny gap so AlarmManager triggers accurately
          targetAlarmTime = now.add(const Duration(seconds: 5));
        }

        if (targetAlarmTime.isAfter(now)) {
          // Schedule native OS AlarmManager AlarmClock (physically powers on screen & launches full screen)
          await scheduleNativeAlarm(
            reminderId: reminder.id,
            triggerAtMillis: targetAlarmTime.millisecondsSinceEpoch,
            title: reminder.title,
          );

          final details = await _getAlarmNotificationDetails(reminder);
          final alarmPayload = 'reminder_alarm:${reminder.id}';
          final alarmTitle = '🚨 ${reminder.title}';
          final alarmBody = reminder.description?.isNotEmpty == true
              ? reminder.description!
              : 'Alarm time reached for ${reminder.title}';

          try {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16 + 1,
              title: alarmTitle,
              body: alarmBody,
              scheduledDate: targetAlarmTime,
              notificationDetails: details,
              androidScheduleMode: exactAlarmScheduleMode,
              payload: alarmPayload,
            );
          } catch (e) {
            debugPrint('Failed to schedule with $exactAlarmScheduleMode, falling back: $e');
            try {
              // First fallback: exactAllowWhileIdle
              await _localNotifications.zonedSchedule(
                id: notificationId * 16 + 1,
                title: alarmTitle,
                body: alarmBody,
                scheduledDate: targetAlarmTime,
                notificationDetails: details,
                androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
                payload: alarmPayload,
              );
            } catch (e2) {
              // Second fallback: inexactAllowWhileIdle
              debugPrint('Failed exactAllowWhileIdle, falling back to inexactAllowWhileIdle: $e2');
              await _localNotifications.zonedSchedule(
                id: notificationId * 16 + 1,
                title: alarmTitle,
                body: alarmBody,
                scheduledDate: targetAlarmTime,
                notificationDetails: details,
                androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
                payload: alarmPayload,
              );
            }
          }
        }
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

    final canExact = await canScheduleExactAlarms();
    final repeatingScheduleMode = canExact
        ? fln.AndroidScheduleMode.exactAllowWhileIdle
        : fln.AndroidScheduleMode.inexactAllowWhileIdle;

    final advanceMinutes = reminder.advanceMinutes;

    try {
      // Multi-day repeats (Weekdays, Weekends, Custom days)
      if (reminder.repeatType == RepeatType.weekdays ||
          reminder.repeatType == RepeatType.weekends ||
          reminder.repeatType == RepeatType.custom) {
        List<int> targetDays;
        if (reminder.repeatType == RepeatType.weekdays) {
          targetDays = const [1, 2, 3, 4, 5]; // Mon - Fri
        } else if (reminder.repeatType == RepeatType.weekends) {
          targetDays = const [6, 7]; // Sat - Sun
        } else {
          targetDays = (reminder.repeatDays != null && reminder.repeatDays!.isNotEmpty)
              ? reminder.repeatDays!
              : [reminder.scheduledAt.weekday];
        }

        for (final day in targetDays) {
          final instance = _nextInstanceOfWeekdayAndTime(
            day,
            reminder.scheduledAt.hour,
            reminder.scheduledAt.minute,
          );

          // Advance warning for this day
          if (reminder.warningEnabled && advanceMinutes > 0) {
            final warnInstance = instance.subtract(Duration(minutes: advanceMinutes));
            final warningPayload = 'reminder_warning:${reminder.id}';
            final warningDetails = _getWarningNotificationDetails(reminder);
            try {
              await _localNotifications.zonedSchedule(
                id: notificationId * 16 + day * 2,
                title: '⏰ Upcoming Reminder',
                body: '${reminder.title} starts in $advanceMinutes minutes',
                scheduledDate: warnInstance,
                notificationDetails: warningDetails,
                androidScheduleMode: repeatingScheduleMode,
                matchDateTimeComponents: fln.DateTimeComponents.dayOfWeekAndTime,
                payload: warningPayload,
              );
            } catch (_) {}
          }

          // Exact alarm for this day
          if (reminder.alarmEnabled || reminder.hasAlarm) {
            final details = await _getAlarmNotificationDetails(reminder);
            final alarmPayload = 'reminder_recurring:${reminder.id}';
            try {
              await _localNotifications.zonedSchedule(
                id: notificationId * 16 + day * 2 + 1,
                title: '🚨 ${reminder.title}',
                body: reminder.description?.isNotEmpty == true
                    ? reminder.description!
                    : 'Recurring alarm for ${reminder.title}',
                scheduledDate: instance,
                notificationDetails: details,
                androidScheduleMode: repeatingScheduleMode,
                matchDateTimeComponents: fln.DateTimeComponents.dayOfWeekAndTime,
                payload: alarmPayload,
              );
            } catch (e) {
              debugPrint('Failed scheduling repeat for weekday $day: $e');
            }
          }
        }

        // Schedule native AlarmClock for the earliest upcoming day instance
        if (reminder.alarmEnabled || reminder.hasAlarm) {
          tz.TZDateTime? earliest;
          for (final day in targetDays) {
            final inst = _nextInstanceOfWeekdayAndTime(
              day,
              reminder.scheduledAt.hour,
              reminder.scheduledAt.minute,
            );
            if (earliest == null || inst.isBefore(earliest)) {
              earliest = inst;
            }
          }
          if (earliest != null) {
            await scheduleNativeAlarm(
              reminderId: reminder.id,
              triggerAtMillis: earliest.millisecondsSinceEpoch,
              title: reminder.title,
            );
          }
        }
        return;
      }

      // Single component repeats (Daily, Weekly, Monthly)
      while (scheduledDate.isBefore(now)) {
        if (reminder.repeatType == RepeatType.daily) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        } else if (reminder.repeatType == RepeatType.weekly) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        } else if (reminder.repeatType == RepeatType.monthly) {
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
      if (reminder.repeatType == RepeatType.daily) {
        matchComponents = fln.DateTimeComponents.time;
      } else if (reminder.repeatType == RepeatType.weekly) {
        matchComponents = fln.DateTimeComponents.dayOfWeekAndTime;
      } else if (reminder.repeatType == RepeatType.monthly) {
        matchComponents = fln.DateTimeComponents.dayOfMonthAndTime;
      }

      if (reminder.warningEnabled && advanceMinutes > 0) {
        final warningDate = scheduledDate.subtract(Duration(minutes: advanceMinutes));
        if (warningDate.isAfter(now)) {
          final warningPayload = 'reminder_warning:${reminder.id}';
          final warningDetails = _getWarningNotificationDetails(reminder);
          try {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16,
              title: '⏰ Upcoming Reminder',
              body: '${reminder.title} starts in $advanceMinutes minutes',
              scheduledDate: warningDate,
              notificationDetails: warningDetails,
              androidScheduleMode: repeatingScheduleMode,
              matchDateTimeComponents: matchComponents,
              payload: warningPayload,
            );
          } catch (e) {
            await _localNotifications.zonedSchedule(
              id: notificationId * 16,
              title: '⏰ Upcoming Reminder',
              body: '${reminder.title} starts in $advanceMinutes minutes',
              scheduledDate: warningDate,
              notificationDetails: warningDetails,
              androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: matchComponents,
              payload: warningPayload,
            );
          }
        }
      }

      if (reminder.alarmEnabled || reminder.hasAlarm) {
        final details = await _getAlarmNotificationDetails(reminder);
        final alarmPayload = 'reminder_recurring:${reminder.id}';
        final alarmTitle = '🚨 ${reminder.title}';
        final alarmBody = reminder.description?.isNotEmpty == true
            ? reminder.description!
            : 'Recurring alarm for ${reminder.title}';

        try {
          await _localNotifications.zonedSchedule(
            id: notificationId * 16 + 1,
            title: alarmTitle,
            body: alarmBody,
            scheduledDate: scheduledDate,
            notificationDetails: details,
            androidScheduleMode: repeatingScheduleMode,
            matchDateTimeComponents: matchComponents,
            payload: alarmPayload,
          );
        } catch (e) {
          debugPrint('Failed repeating exactAllowWhileIdle, falling back: $e');
          await _localNotifications.zonedSchedule(
            id: notificationId * 16 + 1,
            title: alarmTitle,
            body: alarmBody,
            scheduledDate: scheduledDate,
            notificationDetails: details,
            androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: matchComponents,
            payload: alarmPayload,
          );
        }

        // Schedule native AlarmClock for the upcoming repeating instance
        await scheduleNativeAlarm(
          reminderId: reminder.id,
          triggerAtMillis: scheduledDate.millisecondsSinceEpoch,
          title: reminder.title,
        );
      }
    } catch (e) {
      debugPrint('Warning: Failed to schedule repeating notification: $e');
    }
  }

  /// Cancels any scheduled notification or alarm for the given reminder id
  Future<void> cancelNotification(String id) async {
    await cancelNativeAlarm(id);
    final notificationId = _getNotificationId(id);
    try {
      // Cancel standard slots
      await _localNotifications.cancel(id: notificationId * 16);
      await _localNotifications.cancel(id: notificationId * 16 + 1);
      // Cancel weekday slots (1..7)
      for (int d = 1; d <= 7; d++) {
        await _localNotifications.cancel(id: notificationId * 16 + d * 2);
        await _localNotifications.cancel(id: notificationId * 16 + d * 2 + 1);
      }
      // Cancel legacy slots for backward compatibility
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

      if (!reminder.isCompleted && (reminder.alarmEnabled || reminder.warningEnabled || reminder.hasAlarm)) {
        if (reminder.isRepeating && reminder.repeatType != RepeatType.none) {
          await scheduleRepeatingNotification(reminder: reminder);
        } else if (reminder.scheduledAt.isAfter(now)) {
          await scheduleNotification(reminder: reminder);
        }
      }
    }
  }

  fln.NotificationDetails _getWarningNotificationDetails(Reminder reminder) {
    final isVibrating = reminder.alarmVibrationEnabled && reminder.vibrationPattern != 'off';
    final vibrationList = _getVibrationPattern(reminder.vibrationPattern);

    return fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'reminder_channel_v2',
        'Reminder Notifications',
        channelDescription: 'Advance reminder notifications',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        playSound: reminder.alarmSoundEnabled,
        enableVibration: isVibrating,
        vibrationPattern: isVibrating ? vibrationList : null,
        category: fln.AndroidNotificationCategory.reminder,
        fullScreenIntent: true,
        audioAttributesUsage: fln.AudioAttributesUsage.notification,
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
    
    final isVibrating = reminder.alarmVibrationEnabled && reminder.vibrationPattern != 'off';
    final vibrationList = _getVibrationPattern(reminder.vibrationPattern);

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
        
    String channelId = 'alarm_channel_v5';
    fln.AndroidNotificationSound? soundSource;
    String channelName = 'Reminder Alarms';
    
    if (androidPlugin != null) {
      if (!reminder.alarmSoundEnabled) {
        channelId = 'alarm_channel_v5_silent';
        channelName = 'Silent Alarms';
        await androidPlugin.createNotificationChannel(
          fln.AndroidNotificationChannel(
            channelId,
            channelName,
            description: 'Alarms without sound',
            importance: fln.Importance.max,
            playSound: false,
            enableVibration: isVibrating,
            vibrationPattern: isVibrating ? vibrationList : null,
            enableLights: true,
            audioAttributesUsage: fln.AudioAttributesUsage.alarm,
          ),
        );
      } else {
        final isBuiltIn = builtInRingtones.any((r) => r.id == ringtoneId);
        
        if (isBuiltIn) {
          channelId = 'alarm_channel_v5_$ringtoneId';
          soundSource = fln.RawResourceAndroidNotificationSound(ringtoneId);
          final ringtoneObj = builtInRingtones.firstWhere(
            (r) => r.id == ringtoneId,
            orElse: () => BuiltInRingtone(id: ringtoneId, name: ringtoneId),
          );
          channelName = 'Alarm Sound (${ringtoneObj.name})';
          await androidPlugin.createNotificationChannel(
            fln.AndroidNotificationChannel(
              channelId,
              channelName,
              description: 'Exact time reminder alarm with ${ringtoneObj.name}',
              importance: fln.Importance.max,
              playSound: true,
              enableVibration: isVibrating,
              vibrationPattern: isVibrating ? vibrationList : null,
              enableLights: true,
              audioAttributesUsage: fln.AudioAttributesUsage.alarm,
              sound: soundSource,
            ),
          );
        } else {
          final customFile = File(ringtoneId);
          String? contentUri;
          if (customFile.existsSync()) {
            try {
              contentUri = await _settingsChannel.invokeMethod<String>(
                'getMediaUriForFile',
                {'path': customFile.absolute.path},
              );
            } catch (e) {
              debugPrint('Error resolving media content URI: $e');
            }
          }

          if (contentUri != null && contentUri.isNotEmpty) {
            final hash = ringtoneId.hashCode.abs();
            channelId = 'alarm_channel_v5_custom_$hash';
            soundSource = fln.UriAndroidNotificationSound(contentUri);
            channelName = 'Custom Alarm Sound';
            await androidPlugin.createNotificationChannel(
              fln.AndroidNotificationChannel(
                channelId,
                channelName,
                description: 'Exact time reminder alarm with custom sound',
                importance: fln.Importance.max,
                playSound: true,
                enableVibration: isVibrating,
                vibrationPattern: isVibrating ? vibrationList : null,
                enableLights: true,
                audioAttributesUsage: fln.AudioAttributesUsage.alarm,
                sound: soundSource,
              ),
            );
          } else {
            // Fallback to high priority morning_breeze raw sound so sound is guaranteed to play
            channelId = 'alarm_channel_v5_morning_breeze';
            soundSource = const fln.RawResourceAndroidNotificationSound('morning_breeze');
            channelName = 'Alarm Sound (Morning Breeze)';
            await androidPlugin.createNotificationChannel(
              fln.AndroidNotificationChannel(
                channelId,
                channelName,
                description: 'Exact time reminder alarm with Morning Breeze sound',
                importance: fln.Importance.max,
                playSound: true,
                enableVibration: isVibrating,
                vibrationPattern: isVibrating ? vibrationList : null,
                enableLights: true,
                audioAttributesUsage: fln.AudioAttributesUsage.alarm,
                sound: soundSource,
              ),
            );
          }
        }
      }
    }

    return fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Exact time reminder alarms',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        playSound: reminder.alarmSoundEnabled,
        sound: reminder.alarmSoundEnabled ? soundSource : null,
        enableVibration: isVibrating,
        vibrationPattern: isVibrating ? vibrationList : null,
        category: fln.AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: fln.NotificationVisibility.public,
        audioAttributesUsage: fln.AudioAttributesUsage.alarm,
        additionalFlags: reminder.alarmSoundEnabled ? Int32List.fromList(<int>[4]) : null,
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

  /// Trigger an immediate test notification with sound and vibration
  Future<void> testNotification() async {
    const details = fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'alarm_channel_v5_morning_breeze',
        'Reminder Alarms (Default)',
        channelDescription: 'Exact time reminder alarms',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        playSound: true,
        enableVibration: true,
        category: fln.AndroidNotificationCategory.alarm,
      ),
      iOS: fln.DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: 9991,
      title: '🔔 Test Notification',
      body: 'Timebell notifications are working properly!',
      notificationDetails: details,
    );
  }

  /// Trigger an immediate advance alert preview
  Future<void> testAdvanceAlert() async {
    const details = fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'reminder_channel_v2',
        'Reminder Notifications',
        channelDescription: 'Advance reminder notifications',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        playSound: true,
        enableVibration: true,
        category: fln.AndroidNotificationCategory.reminder,
      ),
      iOS: fln.DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: 9992,
      title: '⏰ Advance Alert Preview',
      body: 'Reminder: "Project Review" starts in 15 minutes',
      notificationDetails: details,
    );
  }

  /// Trigger a test vibration pattern
  Future<void> testVibration(String pattern) async {
    final vibrationList = _getVibrationPattern(pattern);
    final details = fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'vibration_test_channel_${pattern.toLowerCase()}',
        'Vibration Test',
        channelDescription: 'Channel for testing vibration patterns',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
        playSound: false,
        enableVibration: pattern != 'off',
        vibrationPattern: pattern != 'off' ? vibrationList : null,
      ),
      iOS: const fln.DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _localNotifications.show(
      id: 9993,
      title: '📳 Vibration Test ($pattern)',
      body: 'Testing "${pattern.toUpperCase()}" vibration pattern.',
      notificationDetails: details,
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
