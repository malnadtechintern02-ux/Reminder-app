import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/theme/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'app/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Notifications Service
  final notificationService = NotificationService.instance;
  await notificationService.init();

  // Route alarm notifications to the full-screen AlarmScreen
  NotificationService.onAlarmTriggered = (reminderId) {
    appRouter.push('/alarm/$reminderId');
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
