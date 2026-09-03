import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color accentColor = Color(0xFF10B981); // Emerald
  static const Color errorColor = Color(0xFFEF4444); // Red

  static const Color darkBackgroundColor = Color(0xFF0F172A); // Slate 900
  static const Color darkCardColor = Color(0xFF1E293B); // Slate 800
  static const Color darkTextColor = Color(0xFFF8FAFC); // Slate 50
  static const Color darkSubtextColor = Color(0xFF94A3B8); // Slate 400

  static const Color lightBackgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color lightCardColor = Color(0xFFFFFFFF);
  static const Color lightTextColor = Color(0xFF0F172A); // Slate 900
  static const Color lightSubtextColor = Color(0xFF64748B); // Slate 500

  static TextTheme _buildTextTheme(Color textColor, Color subtextColor) {
    return GoogleFonts.poppinsTextTheme().copyWith(
      titleLarge: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 22), // Page titles
      titleMedium: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 16), // Section headings
      titleSmall: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.normal, fontSize: 16), // Normal text
      bodyMedium: GoogleFonts.poppins(color: subtextColor, fontWeight: FontWeight.normal, fontSize: 14), // Normal text secondary
      bodySmall: GoogleFonts.poppins(color: subtextColor, fontWeight: FontWeight.normal, fontSize: 12),
      labelLarge: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500, fontSize: 14), // Buttons
      labelMedium: GoogleFonts.poppins(color: subtextColor, fontWeight: FontWeight.w500, fontSize: 12), // Small labels
      labelSmall: GoogleFonts.poppins(color: subtextColor, fontWeight: FontWeight.w500, fontSize: 11),
    );
  }

  static ThemeData getLightTheme([Color? customPrimary]) {
    final primary = customPrimary ?? primaryColor;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBackgroundColor,
      cardColor: lightCardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextColor),
        titleTextStyle: GoogleFonts.poppins(
          color: lightTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w800, // App/Page titles
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accentColor,
        surface: lightBackgroundColor,
        error: errorColor,
      ),
      textTheme: _buildTextTheme(lightTextColor, lightSubtextColor),
      cardTheme: CardThemeData(
        color: lightCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData getDarkTheme([Color? customPrimary]) {
    final primary = customPrimary ?? primaryColor;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackgroundColor,
      cardColor: darkCardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextColor),
        titleTextStyle: GoogleFonts.poppins(
          color: darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accentColor,
        surface: darkBackgroundColor,
        error: errorColor,
      ),
      textTheme: _buildTextTheme(darkTextColor, darkSubtextColor),
      cardTheme: CardThemeData(
        color: darkCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
