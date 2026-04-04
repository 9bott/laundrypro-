import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:laundrypro/l10n/app_localizations.dart';

import '../../core/constants/app_colors.dart';
import '../../core/locale/app_locale_controller.dart';

/// Three-way language picker: العربية 🇸🇦, English 🇬🇧, বাংলা 🇧🇩.
/// Persists via [localeProvider] (SharedPreferences).
class AppLanguageSelector extends ConsumerWidget {
  const AppLanguageSelector({
    super.key,
    this.onLanguageApplied,
    this.dense = false,
  });

  /// e.g. sync `preferred_language` for customer profile.
  final Future<void> Function(String languageCode)? onLanguageApplied;

  final bool dense;

  static const _codes = ['ar', 'en', 'bn'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      '${l10n.arabic} 🇸🇦',
      '${l10n.english} 🇬🇧',
      '${l10n.bengali} 🇧🇩',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            l10n.language,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: dense ? 13 : 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        for (var i = 0; i < _codes.length; i++)
          _LanguageRow(
            label: labels[i],
            selected: _codes[i] == current,
            dense: dense,
            onTap: () async {
              if (_codes[i] == current) return;
              ref.read(localeProvider.notifier).setLocale(Locale(_codes[i]));
              await onLanguageApplied?.call(_codes[i]);
            },
          ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.selected,
    required this.dense,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 8 : 12,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.textHint,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: dense ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
