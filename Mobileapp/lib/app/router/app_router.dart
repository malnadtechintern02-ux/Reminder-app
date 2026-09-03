import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'main_navigation_screen.dart';
import 'route_names.dart';
import 'route_paths.dart';
import '../../features/calendar/presentation/screens/calendar_page.dart';
import '../../features/reminders/presentation/screens/reminders_page.dart';
import '../../features/reminders/presentation/screens/reminder_form_screen.dart';
import '../../features/reminders/presentation/screens/schedule_page.dart';
import '../../features/settings/presentation/screens/settings_page.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/pomodoro/presentation/screens/pomodoro_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: RoutePaths.splash,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state,
          StatefulNavigationShell navigationShell) {
        return MainNavigationScreen(navigationShell: navigationShell);
      },
      branches: [
        // Branch for Schedule
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.schedule,
              name: RouteNames.schedule,
              builder: (context, state) => const SchedulePage(),
            ),
          ],
        ),
        // Branch for Reminders
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.reminders,
              name: RouteNames.reminders,
              builder: (context, state) => const RemindersPage(),
              routes: [
                GoRoute(
                  // create reminder path without slash since it's a nested route
                  path: 'create',
                  name: RouteNames.createReminder,
                  builder: (context, state) => const ReminderFormScreen(),
                ),
                GoRoute(
                  path: 'edit/:id',
                  name: RouteNames.editReminder,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return ReminderFormScreen(reminderId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        // Branch for Calendar
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.calendar,
              name: RouteNames.calendar,
              builder: (context, state) => const CalendarPage(),
            ),
          ],
        ),
        // Branch for Pomodoro
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.pomodoro,
              name: RouteNames.pomodoro,
              builder: (context, state) => const PomodoroPage(),
            ),
          ],
        ),
        // Branch for Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.settings,
              name: RouteNames.settings,
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
