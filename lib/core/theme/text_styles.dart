import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Typography helpers — Material 3 type roles with brand colors.
abstract final class AppTextStyles {
  static const String _fontFamily = 'Roboto';

  static TextTheme textTheme(ColorScheme colors) {
    return TextTheme(
      displayLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.onPrimary,
      ),
    );
  }
}
