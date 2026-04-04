import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/biometric_service.dart';
import '../../l10n/app_localizations.dart';

/// Optional login with device biometrics (splash). Matches profile & staff UI spec.
class BiometricToggle extends StatefulWidget {
  const BiometricToggle({super.key});

  @override
  State<BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends State<BiometricToggle> {
  bool _availChecked = false;
  bool _available = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final avail = await BiometricService.isAvailable();
    final en = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _availChecked = true;
      _available = avail;
      _enabled = en;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_availChecked && !_available) return const SizedBox.shrink();

    if (!_availChecked) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.fingerprint,
          color: AppColors.primary,
          size: 24,
        ),
      ),
      title: Text(
        l10n.signInWithBiometrics,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        _enabled ? l10n.statusOn : l10n.statusOff,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: _enabled ? AppColors.success : AppColors.textHint,
        ),
      ),
      trailing: Switch(
        value: _enabled,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.45),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        onChanged: (val) async {
          if (val) {
            final ok = await BiometricService.authenticate();
            if (!ok) return;
          }
          await BiometricService.setEnabled(val);
          if (!mounted) return;
          setState(() => _enabled = val);
        },
      ),
    );
  }
}
