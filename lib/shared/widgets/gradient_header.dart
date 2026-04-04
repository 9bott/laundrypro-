import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.pillText,
    this.topPadding = 16,
    this.bottomPadding = 20,
    this.radius = 24,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? pillText;
  final double topPadding;
  final double bottomPadding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.blueGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + topPadding, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textOnBlue,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.45,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (pillText != null && pillText!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pillText!,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

