import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import '../features/settings/providers/settings_provider.dart';

const List<Color> appAccentColors = [
  Color(0xFF6366F1), // Indigo (default)
  Color(0xFF10B981), // Emerald
  Color(0xFF8B5CF6), // Purple
  Color(0xFFF59E0B), // Amber
  Color(0xFFEF4444), // Red
];

class ReminderApp extends ConsumerWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      title: 'Reminder App',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.getLightTheme(primaryColor),
      darkTheme: AppTheme.getDarkTheme(primaryColor),
      routerConfig: appRouter,
    );
  }
}
