import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;

/// Top-level background message handler required by Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('FCM Background Message [${message.messageId}]: ${message.notification?.title}');
}

class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();

  FirebaseService._internal();

  late final FirebaseAnalytics analytics;
  late final FirebaseCrashlytics crashlytics;
  late final FirebaseMessaging messaging;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final fln.FlutterLocalNotificationsPlugin _localNotifications =
      fln.FlutterLocalNotificationsPlugin();

  static const String fcmChannelId = 'timebell_fcm_channel';
  static const String fcmChannelName = 'General Notifications';
  static const String fcmChannelDesc = 'Push notifications, announcements, and reminders';

  /// Initialize Firebase Core, Crashlytics, Analytics, and Cloud Messaging
  Future<void> init() async {
    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();
      debugPrint('Firebase Core initialized successfully');

      // 2. Initialize Firebase Crashlytics
      crashlytics = FirebaseCrashlytics.instance;
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = crashlytics.recordFlutterFatalError;

      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      if (!kDebugMode) {
        await crashlytics.setCrashlyticsCollectionEnabled(true);
      }
      debugPrint('Firebase Crashlytics initialized');

      // 3. Initialize Firebase Analytics
      analytics = FirebaseAnalytics.instance;
      await analytics.logAppOpen();
      debugPrint('Firebase Analytics initialized');

      // 4. Initialize Firebase Cloud Messaging (FCM)
      messaging = FirebaseMessaging.instance;

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permissions (Android 13+ and iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Notification permission status: ${settings.authorizationStatus}');

      // Create notification channel for FCM on Android
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const fln.AndroidNotificationChannel(
            fcmChannelId,
            fcmChannelName,
            description: fcmChannelDesc,
            importance: fln.Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      // Retrieve FCM Token
      try {
        _fcmToken = await messaging.getToken();
        debugPrint('FCM Token: $_fcmToken');
      } catch (e) {
        debugPrint('Failed to retrieve FCM Token: $e');
      }

      // Listen for Token refreshes
      messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('FCM Token refreshed: $token');
      });

      // Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.notification?.title}');
        _showForegroundNotification(message);
      });

      // Handle notification tap when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from FCM notification: ${message.data}');
      });

      // Handle cold start from notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App cold-started from FCM notification: ${initialMessage.data}');
      }
    } catch (e, stack) {
      debugPrint('Error initializing Firebase services: $e\n$stack');
    }
  }

  /// Show a system notification when an FCM push is received in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = fln.AndroidNotificationDetails(
      fcmChannelId,
      fcmChannelName,
      channelDescription: fcmChannelDesc,
      importance: fln.Importance.high,
      priority: fln.Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = fln.DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = fln.NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'Time Bell',
      body: notification.body,
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }

  // --- Analytics Helper Methods ---

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics logEvent error: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    try {
      await analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics logScreenView error: $e');
    }
  }

  Future<void> setUserId(String? userId) async {
    try {
      await analytics.setUserId(id: userId);
      if (userId != null) {
        await crashlytics.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('Analytics setUserId error: $e');
    }
  }

  Future<void> logReminderCreated({
    required String category,
    required bool isRecurring,
  }) async {
    await logEvent('reminder_created', {
      'category': category,
      'is_recurring': isRecurring ? 1 : 0,
    });
  }

  Future<void> logAlarmFired(String reminderId) async {
    await logEvent('alarm_fired', {
      'reminder_id': reminderId,
    });
  }

  Future<void> recordCustomError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Crashlytics recordCustomError error: $e');
    }
  }
}
