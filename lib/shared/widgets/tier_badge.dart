import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Loyalty tier (bronze / silver / gold), or the active subscription product
/// label when [activePlanName] / [activePlanNameAr] are set on the customer row.
class TierBadge extends StatelessWidget {
  const TierBadge({
    required this.tier,
    super.key,
    this.activePlanName,
    this.activePlanNameAr,
    this.onDarkBackground = false,
    this.dense = true,
  });

  final String tier;
  final String? activePlanName;
  final String? activePlanNameAr;
  final bool onDarkBackground;
  final bool dense;

  bool get _showPlan {
    final en = activePlanName?.trim() ?? '';
    final ar = activePlanNameAr?.trim() ?? '';
    return en.isNotEmpty || ar.isNotEmpty;
  }

  String _planText(AppLocalizations l10n) {
    final isAr = l10n.localeName.startsWith('ar');
    final ar = activePlanNameAr?.trim() ?? '';
    final en = activePlanName?.trim() ?? '';
    if (isAr && ar.isNotEmpty) return ar;
    if (en.isNotEmpty) return en;
    return ar;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = dense ? 11.0 : 14.0;
    final padH = dense ? 10.0 : 12.0;
    final padV = dense ? 4.0 : 6.0;

    if (_showPlan) {
      final text = _planText(l10n);
      late Color bg;
      late Color fg;
      if (onDarkBackground) {
        bg = Colors.white.withValues(alpha: 0.18);
        fg = Colors.white;
      } else {
        bg = AppColors.txSubscriptionBg;
        fg = AppColors.iconSubscriptionFg;
      }
      return Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: onDarkBackground ? 0.45 : 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: dense ? 14 : 18, color: fg),
            SizedBox(width: dense ? 4 : 6),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      );
    }

    late Color bg;
    late Color fg;
    late String text;
    switch (tier.toLowerCase()) {
      case 'bronze':
        if (onDarkBackground) {
          bg = Colors.white.withValues(alpha: 0.15);
          fg = AppColors.goldLight;
        } else {
          bg = const Color(0xFFFFEDD5);
          fg = AppColors.tierBronze;
        }
        text = '${l10n.bronze} 🥉';
        break;
      case 'silver':
        if (onDarkBackground) {
          bg = Colors.white.withValues(alpha: 0.18);
          fg = Colors.white;
        } else {
          bg = const Color(0xFFF1F5F9);
          fg = AppColors.tierSilver;
        }
        text = '${l10n.silver} 🥈';
        break;
      case 'gold':
        if (onDarkBackground) {
          bg = AppColors.gold.withValues(alpha: 0.25);
          fg = AppColors.goldLight;
        } else {
          bg = AppColors.goldTint;
          fg = AppColors.tierGold;
        }
        text = '${l10n.gold} 🥇';
        break;
      default:
        if (onDarkBackground) {
          bg = Colors.white.withValues(alpha: 0.15);
          fg = AppColors.goldLight;
        } else {
          bg = const Color(0xFFFFEDD5);
          fg = AppColors.tierBronze;
        }
        text = '${l10n.bronze} 🥉';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: onDarkBackground ? 0.4 : 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
