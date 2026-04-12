import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData theme() {
    final colorScheme = const ColorScheme.light(
      surface: AppColors.surface,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textPrimary,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.border,
      surfaceContainerHighest: AppColors.surfaceAlt,
    );

    final baseLight = ThemeData(brightness: Brightness.light);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseLight.textTheme)
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryTint,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark);
          }
          return const IconThemeData(color: AppColors.textHint);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textHint,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  @Deprecated('Use AppTheme.theme()')
  static ThemeData dark() => theme();

  @Deprecated('Use AppTheme.theme()')
  static ThemeData light() => theme();
}
