import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AppLogoLoader extends StatefulWidget {
  const AppLogoLoader({
    super.key,
    this.size = 140,
    this.background = Colors.transparent,
    this.borderRadius = 34,
    this.showShadow = true,
  });

  final double size;
  final Color background;
  final double borderRadius;
  final bool showShadow;

  @override
  State<AppLogoLoader> createState() => _AppLogoLoaderState();
}

class _AppLogoLoaderState extends State<AppLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final scale = disableAnim
        ? const AlwaysStoppedAnimation<double>(1)
        : Tween<double>(begin: 0.97, end: 1.03).animate(
            CurvedAnimation(parent: _ctl, curve: Curves.easeInOut),
          );

    return ScaleTransition(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: widget.showShadow
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/app_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            return const Center(
              child: Icon(
                Icons.local_laundry_service_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            );
          },
        ),
      ),
    );
  }
}

