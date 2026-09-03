import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildNavItem(
                context,
                icon: Icons.schedule_rounded,
                label: 'Schedule',
                index: 0,
              ),
              _buildNavItem(
                context,
                icon: Icons.list_alt_rounded,
                label: 'Reminders',
                index: 1,
              ),
              _buildNavItem(
                context,
                icon: Icons.calendar_month_rounded,
                label: 'Calendar',
                index: 2,
              ),
              _buildNavItem(
                context,
                icon: Icons.timer_rounded,
                label: 'Pomodoro',
                index: 3,
              ),
              _buildNavItem(
                context,
                icon: Icons.settings_rounded,
                label: 'Settings',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required String label, required int index}) {
    final isSelected = navigationShell.currentIndex == index;
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 10.5,
                  ),
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
