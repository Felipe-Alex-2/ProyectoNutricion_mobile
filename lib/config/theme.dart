import 'package:flutter/material.dart';

class AppTheme {
  static const primaryGreen = Color(0xFF206443);
  static const primaryGreenLight = Color(0xFFE6F0EB);
  static const primaryGreenDark = Color(0xFF79C99D);
  static const accentOrange = Color(0xFFE0873E);
  static const accentCoral = Color(0xFFD9534F);
  static const accentBlue = Color(0xFF3B82F6);
  static const premiumGold = Color(0xFFEFC66C);
  static const lightBg = Color(0xFFF7F9F4);
  static const lightSidebar = lightBg;
  static const lightCard = Colors.white;
  static const lightCardHighlight = primaryGreenLight;
  static const lightPillActive = primaryGreenLight;
  static const lightTextPrimary = Color(0xFF172920);
  static const lightTextSecondary = Color(0xFF65756B);
  static const lightTextMuted = Color(0xFF718379);
  static const lightTrack = Color(0xFFE1E8DF);
  static const darkBg = Color(0xFF0D1712);
  static const darkSidebar = darkBg;
  static const darkCard = Color(0xFF18271F);
  static const darkCardAccent = Color(0xFF213D2F);
  static const darkPillActive = Color(0xFF254734);
  static const darkTextPrimary = Color(0xFFEDF5EF);
  static const darkTextSecondary = Color(0xFFADBCB2);
  static const darkTextMuted = Color(0xFF91A398);
  static const darkTrack = Color(0xFF304739);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? primaryGreenDark : primaryGreen;
    final surface = dark ? darkCard : lightCard;
    final foreground = dark ? darkTextPrimary : lightTextPrimary;
    final secondary = dark ? darkTextSecondary : lightTextSecondary;
    final border = dark ? darkTrack : lightTrack;
    final onPrimary = dark ? darkBg : Colors.white;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: dark ? premiumGold : const Color(0xFF9B591F),
          surface: surface,
          onSurface: foreground,
          onSurfaceVariant: secondary,
          outline: dark ? darkTextMuted : lightTextMuted,
          outlineVariant: border,
          surfaceTint: Colors.transparent,
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'NutriSans',
      brightness: brightness,
      colorScheme: scheme,
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark ? darkBg : lightBg,
      primaryColor: primary,
      textTheme: base.textTheme
          .apply(bodyColor: foreground, displayColor: foreground)
          .copyWith(
            headlineMedium: TextStyle(
              fontFamily: 'NutriSans',
              fontSize: 28,
              height: 1.18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.7,
              color: foreground,
            ),
            titleLarge: TextStyle(
              fontFamily: 'NutriSans',
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
              color: foreground,
            ),
            titleMedium: TextStyle(
              fontFamily: 'NutriSans',
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
            bodyLarge: TextStyle(
              fontFamily: 'NutriSans',
              fontSize: 15,
              height: 1.45,
              color: foreground,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'NutriSans',
              fontSize: 14,
              height: 1.4,
              color: foreground,
            ),
            bodySmall: TextStyle(
              fontFamily: 'NutriSans',
              fontSize: 12,
              height: 1.4,
              color: secondary,
            ),
          ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? darkBg : lightBg,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NutriSans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: TextStyle(
          fontFamily: 'NutriSans',
          color: secondary,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          fontFamily: 'NutriSans',
          color: secondary,
          fontSize: 14,
        ),
        prefixIconColor: secondary,
        suffixIconColor: secondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorMaxLines: 3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: rounded,
          textStyle: const TextStyle(
            fontFamily: 'NutriSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: rounded,
          textStyle: const TextStyle(
            fontFamily: 'NutriSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          shape: rounded,
          textStyle: const TextStyle(
            fontFamily: 'NutriSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        checkmarkColor: onPrimary,
        backgroundColor: dark ? darkCard : primaryGreenLight,
        selectedColor: primary,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        height: 72,
        indicatorColor: dark ? darkPillActive : lightPillActive,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'NutriSans',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primary : secondary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? darkCardAccent : primaryGreen,
        contentTextStyle: const TextStyle(
          fontFamily: 'NutriSans',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: rounded,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),
    );
  }
}
