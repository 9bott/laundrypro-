import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// بطاقة صلبة بظل عميق (بدون blur).
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.borderColor,
    this.shadow,
    this.blurSigma = 0,
    this.fillOpacity = 1,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final double blurSigma;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    final bc = borderColor ?? AppColors.border;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(fillOpacity.clamp(0.0, 1.0)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: bc),
        boxShadow: shadow ?? AppColors.cardShadow,
      ),
      child: child,
    );
  }
}
