import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();
    final timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create Notification Channels for Android
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'reminder_channel',
          'Reminder Notifications',
          description: '5 minute reminder notifications',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_channel',
          'Reminder Alarms',
          description: 'Exact time reminder alarms',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'pomodoro_channel',
          'Pomodoro',
          description: 'Pomodoro timer notifications',
          importance: Importance.high,
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
        AndroidFlutterLocalNotificationsPlugin>();
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
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    // Request iOS permissions
    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
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
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final notificationId = _getNotificationId(id);
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    // --------------------------------------------------------
    // 5 MINUTE WARNING
    // --------------------------------------------------------
    final fiveMinutesBefore = tzScheduledDate.subtract(const Duration(minutes: 5));

    if (fiveMinutesBefore.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        id: notificationId * 2,
        title: '⏰ Upcoming Reminder',
        body: '$title starts in 5 minutes',
        scheduledDate: fiveMinutesBefore,
        notificationDetails: _getWarningNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'reminder_warning',
      );
    }

    // --------------------------------------------------------
    // EXACT TIME ALARM
    // --------------------------------------------------------
    if (tzScheduledDate.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        id: notificationId * 2 + 1,
        title: '🚨 Reminder',
        body: title,
        scheduledDate: tzScheduledDate,
        notificationDetails: _getAlarmNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'reminder_alarm',
      );
    }
  }

  Future<void> scheduleRepeatingNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String repeatType,
  }) async {
    final notificationId = _getNotificationId(id);
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    DateTimeComponents? matchComponents;
    if (repeatType == 'daily') {
      matchComponents = DateTimeComponents.time;
    } else if (repeatType == 'weekly') {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (repeatType == 'monthly') {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
    }

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tzScheduledDate,
      notificationDetails: _getAlarmNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
    );
  }

  Future<void> cancelNotification(String id) async {
    final notificationId = _getNotificationId(id);
    await _localNotifications.cancel(id: notificationId * 2);
    await _localNotifications.cancel(id: notificationId * 2 + 1);
  }

  NotificationDetails _getWarningNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel',
        'Reminder Notifications',
        channelDescription: '5 minute reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  NotificationDetails _getAlarmNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel',
        'Reminder Alarms',
        channelDescription: 'Exact time reminder alarms',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze',
            'SNOOZE',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'DISMISS',
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> showPomodoroFinished() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro',
        channelDescription: 'Pomodoro timer',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
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
