import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// بطاقة مرتفعة بإطار لامع (بدون زجاج حقيقي).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.borderColor,
    this.borderWidth = 1,
    this.blurSigma = 0,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final fill = tint ?? AppColors.surface;
    final bc = borderColor ?? AppColors.primary.withOpacity(0.28);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: bc, width: borderWidth),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}
