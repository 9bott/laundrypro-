import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/biometric_service.dart';
import '../../l10n/app_localizations.dart';

/// Biometric login toggle (Face ID / fingerprint). Hidden if device unsupported.
class BiometricSettingsListTile extends StatefulWidget {
  const BiometricSettingsListTile({super.key});

  @override
  State<BiometricSettingsListTile> createState() =>
      _BiometricSettingsListTileState();
}

class _BiometricSettingsListTileState extends State<BiometricSettingsListTile> {
  late Future<bool> _availableFuture;
  late Future<bool> _enabledFuture;

  @override
  void initState() {
    super.initState();
    _reloadFutures();
  }

  void _reloadFutures() {
    _availableFuture = BiometricService.isAvailable();
    _enabledFuture = BiometricService.isEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _availableFuture,
      builder: (context, availableSnap) {
        if (!(availableSnap.data ?? false)) return const SizedBox.shrink();
        return FutureBuilder<bool>(
          future: _enabledFuture,
          builder: (context, enabledSnap) {
            final enabled = enabledSnap.data ?? false;
            final l10n = AppLocalizations.of(context)!;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                  size: 22,
                ),
              ),
              title: Text(
                l10n.biometricLoginTitle,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                enabled ? l10n.statusOn : l10n.statusOff,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: enabled ? AppColors.success : AppColors.textHint,
                ),
              ),
              trailing: Switch(
                value: enabled,
                activeThumbColor: AppColors.primary,
                onChanged: (val) async {
                  if (val) {
                    final ok = await BiometricService.authenticate();
                    if (!ok) return;
                  }
                  await BiometricService.setEnabled(val);
                  if (!mounted) return;
                  setState(() {
                    _reloadFutures();
                  });
                },
              ),
            );
          },
        );
      },
    );
  }
}
