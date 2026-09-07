import 'package:flutter/material.dart';

IconData getCategoryIcon(String? iconName) {
  if (iconName == null || iconName.trim().isEmpty) {
    return Icons.label_rounded;
  }
  final key = iconName.trim().toLowerCase();
  switch (key) {
    case 'work':
    case 'briefcase':
    case 'job':
    case 'office':
      return Icons.work_rounded;
    case 'person':
    case 'personal':
    case 'user':
      return Icons.person_rounded;
    case 'book':
    case 'study':
    case 'education':
    case 'school':
    case 'read':
      return Icons.menu_book_rounded;
    case 'shopping':
    case 'shopping_cart':
    case 'shop':
    case 'cart':
    case 'store':
      return Icons.shopping_cart_rounded;
    case 'health':
    case 'favorite':
    case 'heart':
    case 'fitness':
    case 'medical':
    case 'doctor':
    case 'gym':
      return Icons.favorite_rounded;
    case 'sports':
    case 'game':
    case 'games':
    case 'play':
    case 'sport':
      return Icons.sports_soccer_rounded;
    case 'food':
    case 'restaurant':
    case 'eat':
    case 'dinner':
      return Icons.restaurant_rounded;
    case 'travel':
    case 'flight':
    case 'plane':
    case 'trip':
      return Icons.flight_rounded;
    case 'money':
    case 'finance':
    case 'cash':
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'home':
    case 'house':
      return Icons.home_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'music':
      return Icons.music_note_rounded;
    case 'code':
    case 'dev':
      return Icons.code_rounded;
    case 'clock':
    case 'alarm':
    case 'time':
      return Icons.alarm_rounded;
    case 'calendar':
    case 'event':
      return Icons.calendar_today_rounded;
    case 'folder':
      return Icons.folder_rounded;
    default:
      return Icons.label_rounded;
  }
}

Color parseHexColor(String? hexString, {Color defaultColor = const Color(0xFF4F46E5)}) {
  if (hexString == null || hexString.trim().isEmpty) return defaultColor;
  try {
    final clean = hexString.trim().replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return defaultColor;
}

String resolveDefaultCategoryColor(String name, [int index = 0]) {
  final n = name.trim().toLowerCase();
  if (n.contains('health') || n.contains('med') || n.contains('doctor') || n.contains('heart')) {
    return '#EF4444'; // Red
  }
  if (n.contains('sport') || n.contains('game') || n.contains('gym') || n.contains('fitness') || n.contains('play')) {
    return '#F97316'; // Vibrant Orange
  }
  if (n.contains('work') || n.contains('office') || n.contains('job')) {
    return '#2196F3'; // Blue
  }
  if (n.contains('personal') || n.contains('life') || n.contains('home')) {
    return '#4CAF50'; // Green
  }
  if (n.contains('study') || n.contains('book') || n.contains('education') || n.contains('school')) {
    return '#9C27B0'; // Purple
  }
  if (n.contains('shop') || n.contains('cart') || n.contains('buy')) {
    return '#FF9800'; // Amber
  }

  const palette = [
    '#4F46E5', // Indigo
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#F97316', // Orange
    '#3B82F6', // Blue
    '#14B8A6', // Teal
  ];
  return palette[index % palette.length];
}

Color getPriorityColor(dynamic priority, ThemeData theme) {
  final String name = (priority is String)
      ? priority.toLowerCase()
      : (priority?.name?.toString().toLowerCase() ?? 'low');

  if (name.contains('urgent') || name.contains('critical') || name.contains('emergency')) {
    return const Color(0xFFE11D48); // Vivid Red / Urgent
  }
  if (name.contains('high')) {
    return theme.colorScheme.error; // Orange-Red / High
  }
  if (name.contains('medium') || name.contains('normal')) {
    return Colors.amber.shade800; // Amber / Medium
  }
  if (name.contains('low')) {
    return const Color(0xFF10B981); // Emerald / Low
  }
  return theme.colorScheme.primary;
}

