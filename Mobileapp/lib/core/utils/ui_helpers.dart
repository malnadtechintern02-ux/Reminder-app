import 'package:flutter/material.dart';

IconData getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'work':
      return Icons.work_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'shopping_cart':
      return Icons.shopping_cart_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color parseHexColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}
