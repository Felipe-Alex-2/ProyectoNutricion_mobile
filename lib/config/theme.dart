import 'package:flutter/material.dart';

class AppTheme {
  // NutriSalud Brand Colors
  static const primaryGreen = Color(0xFF206443);
  static const primaryGreenLight = Color(0xFFE6F0EB);
  static const primaryGreenDark = Color(0xFF2E7D56);

  static const accentOrange = Color(0xFFE0873E);
  static const accentCoral = Color(0xFFD9534F);
  static const accentBlue = Color(0xFF3B82F6);

  // Light Mode Colors (Matched exactly to web CSS variables)
  static const lightBg = Color(0xFFF4EBD9);
  static const lightSidebar = Color(0xFFFAF5E8);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardHighlight = Color(0xFFEADBB8);
  static const lightPillActive = Color(0xFFE8DAB4);
  static const lightTextPrimary = Color(0xFF172920);
  static const lightTextSecondary = Color(0xFF65756B);
  static const lightTextMuted = Color(0xFF8E9E94);
  static const lightTrack = Color(0xFFEADBB8);

  // Dark Mode Colors (Matched exactly to web CSS variables)
  static const darkBg = Color(0xFF0D1310);
  static const darkSidebar = Color(0xFF090E0C);
  static const darkCard = Color(0xFF18221D);
  static const darkCardAccent = Color(0xFF214132);
  static const darkPillActive = Color(0xFF1C382B);
  static const darkTextPrimary = Color(0xFFE6F0EA);
  static const darkTextSecondary = Color(0xFF90A398);
  static const darkTextMuted = Color(0xFF5B6F63);
  static const darkTrack = Color(0xFF1C382B);

  // Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentOrange,
        surface: lightCard,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x0A000000)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryGreenDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreenDark,
        secondary: accentOrange,
        surface: darkCard,
        onPrimary: Colors.black,
        onSurface: darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x14FFFFFF)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreenDark,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
