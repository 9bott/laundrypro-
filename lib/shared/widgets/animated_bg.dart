import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class _AppBackgroundScope extends InheritedWidget {
  const _AppBackgroundScope({required super.child});

  static bool exists(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppBackgroundScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_AppBackgroundScope oldWidget) => false;
}

/// خلفية فاتحة محايدة مع بريق أزرق خفيف.
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({
    super.key,
    required this.child,
    this.extraOrbs = false,
  });

  final Widget child;
  final bool extraOrbs;

  @override
  Widget build(BuildContext context) {
    // If a global background is already applied (e.g. app-level builder),
    // avoid stacking multiple gradients/orbs.
    if (_AppBackgroundScope.exists(context)) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF7F7FF), // requested: very light bluish
                Color(0xFFE6F0FB), // requested: pale blue
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _blob(240, AppColors.primary.withValues(alpha: 0.10)),
        ),
        Positioned(
          top: 140,
          left: -70,
          child: _blob(200, AppColors.surfaceAlt.withValues(alpha: 0.9)),
        ),
        Positioned(
          bottom: 40,
          right: -50,
          child: _blob(180, AppColors.primaryLight.withValues(alpha: 0.10)),
        ),
        if (extraOrbs)
          Positioned(
            bottom: 200,
            left: -40,
            child: _blob(160, AppColors.tertiary.withValues(alpha: 0.06)),
          ),
        _AppBackgroundScope(child: child),
      ],
    );
  }

  static Widget _blob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
