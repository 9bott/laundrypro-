import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class BlueButton extends StatefulWidget {
  const BlueButton({
    required this.onTap,
    required this.label,
    super.key,
    this.loading = false,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final String label;
  final bool loading;
  final bool enabled;

  @override
  State<BlueButton> createState() => _BlueButtonState();
}

class _BlueButtonState extends State<BlueButton> {
  double _scale = 1;

  void _fire() {
    final cb = widget.onTap;
    if (!widget.enabled || widget.loading || cb == null) return;
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled && !widget.loading && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: canTap ? (_) => setState(() => _scale = 0.97) : null,
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: canTap
          ? (_) {
              setState(() => _scale = 1);
              HapticFeedback.lightImpact();
              _fire();
            }
          : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          height: 54,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: AppColors.blueGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: AppColors.blueShadow,
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
