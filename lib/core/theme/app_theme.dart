import 'package:flutter/material.dart';

class AppColors {
  // Primary - Purple
  static const Color primary = Color(0xFF4A148C);
  static const Color primaryLight = Color(0xFF7B1FA2);
  static const Color primaryDark = Color(0xFF2D0060);

  // Secondary - Gold
  static const Color secondary = Color(0xFFFFB300);
  static const Color secondaryLight = Color(0xFFFFD54F);
  static const Color secondaryDark = Color(0xFFFF8F00);
  static const Color goldInk = Color(0xFF805800);

  // Tertiary - Blue
  static const Color blue = Color(0xFF1565C0);
  static const Color blueLight = Color(0xFF42A5F5);
  static const Color blueDark = Color(0xFF0D47A1);

  // Neutral
  static const Color background = Color(0xFFF8F5FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B8A);
  static const Color divider = Color(0xFFE0D7F5);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.blue,
        onTertiary: Colors.white,
        primaryContainer: Color(0xFFEDE3F7),
        onPrimaryContainer: AppColors.primaryDark,
        secondaryContainer: Color(0xFFFFF2C6),
        onSecondaryContainer: AppColors.goldInk,
        tertiaryContainer: Color(0xFFE3EFFD),
        onTertiaryContainer: AppColors.blueDark,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: AppColors.textPrimary,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.primary,
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: Color(0x1A4A148C), // 10% opacity of primary
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.secondaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.secondaryLight,
        selectedIconTheme: IconThemeData(color: AppColors.primaryDark),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle:
            TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),

      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
    );
  }
}
