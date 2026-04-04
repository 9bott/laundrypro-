import 'package:flutter/material.dart';

/// **iOS-style blue + neutral surfaces** — Primary `#007AFF`, Secondary `#F8FAFC`,
/// Tertiary accent `#D75600`, Neutral `#F0F4F8`.
class AppColors {
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryMid = Color(0xFF3399FF);
  static const Color primaryLight = Color(0xFF66B3FF);
  static const Color primaryTint = Color(0xFFE5F1FF);
  static const Color primaryBorder = Color(0xFFB3D7FF);
  static const Color primaryDark = Color(0xFF0056B3);

  /// لوحة المعايرة: أزرق أساسي، رمادي فاتح للأزرار الثانوية، برتقالي للتمييز.
  static const Color secondaryPalette = Color(0xFFF8FAFC);
  static const Color tertiary = Color(0xFFD75600);
  static const Color neutral = Color(0xFFF0F4F8);

  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8FAFC);

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnBlue = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFFCBD5E1);

  static const Color success = Color(0xFF059669);
  static const Color successTint = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorTint = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningTint = Color(0xFFFEF3C7);

  static const Color gold = Color(0xFFD75600);
  static const Color goldLight = Color(0xFFFF8A4A);
  static const Color goldTint = Color(0xFFFFF4ED);

  static const Color tierBronze = Color(0xFFB45309);
  static const Color tierSilver = Color(0xFF64748B);
  static const Color tierGold = Color(0xFFD75600);

  static const Color txSubscriptionBg = Color(0xFFE8F2FF);
  static const Color iconSubscriptionFg = Color(0xFF007AFF);

  static const List<Color> blueGradient = [
    Color(0xFF0056B3),
    Color(0xFF007AFF),
    Color(0xFF4DA3FF),
  ];

  static List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: Color(0x14007AFF),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> blueShadow = [
    const BoxShadow(
      color: Color(0x40007AFF),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  // ── Legacy aliases ──
  static const Color neonBlue = Color(0xFF66B3FF);
  static const Color neonCyan = Color(0xFF007AFF);
  static const Color neonGold = Color(0xFFFF8A4A);
  static const Color neonGreen = Color(0xFF059669);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF64748B);
  static const Color textDim = Color(0xFF94A3B8);
  static const Color darkBg = Color(0xFFF0F4F8);
  static const Color darkSurface = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFFF8FAFC);
  static const Color glassWhite = Color(0x1A007AFF);
  static const Color glassBorder = Color(0xFFE2E8F0);
  static const Color accentGold = Color(0xFFD75600);
  /// لـ [ColorScheme.secondary] — خلفيات أزرار ثانوية فاتحة.
  static const Color secondary = Color(0xFFF8FAFC);
}
