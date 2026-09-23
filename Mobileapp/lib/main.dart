import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/theme/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_service.dart';
import 'app/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Analytics, Crashlytics, FCM)
  await FirebaseService.instance.init();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Notifications Service
  final notificationService = NotificationService.instance;
  await notificationService.init();

  // Check if app was cold-launched by an alarm notification or full-screen intent
  final launchAlarmId = await notificationService.getLaunchAlarmReminderId();
  if (launchAlarmId != null) {
    await notificationService.wakeUpScreen();
    appRouter = createAppRouter(initialLocation: '/alarm/$launchAlarmId');
  } else {
    appRouter = createAppRouter();
  }

  // Route alarm notifications to the full-screen AlarmScreen when triggered while app is active/background
  NotificationService.onAlarmTriggered = (reminderId) async {
    await notificationService.wakeUpScreen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        appRouter.go('/alarm/$reminderId');
      } catch (e) {
        debugPrint('Error navigating to alarm: $e');
        try {
          appRouter.push('/alarm/$reminderId');
        } catch (_) {}
      }
    });
  };

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ReminderApp(),
    ),
  );
}
