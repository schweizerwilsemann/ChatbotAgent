import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════
  // Light theme — warm, minimal, educational
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBackground,

      // ── AppBar ─────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.scaffoldBackground,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: AppColors.cardBackground,
      ),

      // ── ElevatedButton (primary CTA) ───────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── OutlinedButton / secondary ─────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FilledButton (Material 3) ──────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── TextField / InputDecoration ────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),

      // ── Bottom Navigation ──────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySurface,
        elevation: 0,
        shadowColor: AppColors.shadow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          );
        }),
      ),

      // ── Chips ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primarySurface,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Dialogs ────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),

      // ── Snackbar ───────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),

      // ── Text Theme ─────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Dark theme — simplified, inherits palette structure
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: const Color(0xFF1E1E1E),
        error: AppColors.errorLight,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: const Color(0xFF1E1E1E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        displayMedium:
            TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        displaySmall:
            TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        headlineLarge:
            TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium:
            TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        headlineSmall:
            TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium:
            TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        titleSmall: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge:
            TextStyle(fontWeight: FontWeight.w400, color: Colors.white70),
        bodyMedium:
            TextStyle(fontWeight: FontWeight.w400, color: Colors.white70),
        bodySmall:
            TextStyle(fontWeight: FontWeight.w400, color: Colors.white60),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        labelMedium:
            TextStyle(fontWeight: FontWeight.w500, color: Colors.white70),
        labelSmall:
            TextStyle(fontWeight: FontWeight.w500, color: Colors.white60),
      ),
    );
  }
}
