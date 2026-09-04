import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../features/reminders/domain/entities/reminder.dart';

@pragma('vm:entry-point')
void notificationTapBackground(fln.NotificationResponse notificationResponse) {
  // Handle background actions (like Snooze/Dismiss)
  if (notificationResponse.actionId == 'dismiss') {
    // Just dismiss, Android removes the notification automatically
  } else if (notificationResponse.actionId == 'snooze') {
    // Ideally we would reschedule here, but doing it correctly requires
    // accessing the DB/SharedPreferences from the background isolate.
    // In a real app we'd dispatch to a background worker.
    final idStr = notificationResponse.payload;
    if (idStr != null) {
      // Background isolate rescheduling logic would go here
    }
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final fln.FlutterLocalNotificationsPlugin _localNotifications = fln.FlutterLocalNotificationsPlugin();

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

      await androidPlugin.createNotificationChannel(
        const fln.AndroidNotificationChannel(
          'alarm_channel_v2',
          'Reminder Alarms',
          description: 'Exact time reminder alarms',
          importance: fln.Importance.max,
          playSound: true,
          enableVibration: true,
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
  /// without triggering any system dialogs or redirects.
  Future<bool> areNotificationsPermitted() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      return granted ?? false;
    }
    // On iOS, check if we can show notifications
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
          androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
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
          title: '🚨 Reminder',
          body: reminder.title,
          scheduledDate: tzScheduledDate,
          notificationDetails: details,
          androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'reminder_alarm',
        );
      }
    } catch (e) {
      print('Warning: Failed to schedule notification: $e');
    }
  }

  Future<void> scheduleRepeatingNotification({
    required Reminder reminder,
  }) async {
    final notificationId = _getNotificationId(reminder.id);
    final tzScheduledDate = tz.TZDateTime.from(reminder.scheduledAt, tz.local);

    fln.DateTimeComponents? matchComponents;
    if (reminder.repeatType.name == 'daily') {
      matchComponents = fln.DateTimeComponents.time;
    } else if (reminder.repeatType.name == 'weekly') {
      matchComponents = fln.DateTimeComponents.dayOfWeekAndTime;
    } else if (reminder.repeatType.name == 'monthly') {
      matchComponents = fln.DateTimeComponents.dayOfMonthAndTime;
    }

    try {
      if (reminder.alarmEnabled) {
        final details = await _getAlarmNotificationDetails(reminder);
        await _localNotifications.zonedSchedule(
          id: notificationId,
          title: reminder.title,
          body: reminder.description ?? 'You have a reminder!',
          scheduledDate: tzScheduledDate,
          notificationDetails: details,
          androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchComponents,
        );
      }
    } catch (e) {
      print('Warning: Failed to schedule repeating notification: $e');
    }
  }

  Future<void> cancelNotification(String id) async {
    final notificationId = _getNotificationId(id);
    try {
      await _localNotifications.cancel(id: notificationId * 2);
      await _localNotifications.cancel(id: notificationId * 2 + 1);
      await _localNotifications.cancel(id: notificationId);
    } catch (e) {
      print('Warning: Failed to cancel notification: $e');
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
    final defaultRingtone = prefs.getString('defaultRingtone') ?? 'morning_alarm';
    final ringtoneId = reminder.ringtone ?? defaultRingtone;
    
    // Create the channel dynamically
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>();
        
    String channelId = 'alarm_channel_v2';
    
    if (androidPlugin != null && reminder.alarmSoundEnabled) {
      // Is built-in or custom?
      final isBuiltIn = ['morning_alarm', 'classic_alarm', 'digital_alarm', 'gentle_alarm'].contains(ringtoneId);
      
      if (isBuiltIn) {
        channelId = 'alarm_channel_$ringtoneId';
        await androidPlugin.createNotificationChannel(
          fln.AndroidNotificationChannel(
            channelId,
            'Alarm: $ringtoneId',
            description: 'Exact time reminder alarm with custom sound',
            importance: fln.Importance.max,
            playSound: true,
            enableVibration: reminder.alarmVibrationEnabled,
            sound: fln.RawResourceAndroidNotificationSound(ringtoneId),
          ),
        );
      } else {
        // Custom URI sound
        final hash = ringtoneId.hashCode;
        channelId = 'alarm_channel_custom_$hash';
        // Need to check if file exists
        if (File(ringtoneId).existsSync()) {
          await androidPlugin.createNotificationChannel(
            fln.AndroidNotificationChannel(
              channelId,
              'Alarm: Custom Sound',
              description: 'Exact time reminder alarm with custom sound',
              importance: fln.Importance.max,
              playSound: true,
              enableVibration: reminder.alarmVibrationEnabled,
              sound: fln.UriAndroidNotificationSound('file://$ringtoneId'),
            ),
          );
        } else {
           channelId = 'alarm_channel_v2'; // fallback to default
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
        sound: ringtoneId.endsWith('.wav') || ringtoneId.endsWith('.mp3') ? ringtoneId : '$ringtoneId.wav',
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
