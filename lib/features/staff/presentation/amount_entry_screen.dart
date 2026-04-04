import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_card.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

class StaffAmountEntryScreen extends ConsumerStatefulWidget {
  const StaffAmountEntryScreen({super.key});

  @override
  ConsumerState<StaffAmountEntryScreen> createState() =>
      _StaffAmountEntryScreenState();
}

class _StaffAmountEntryScreenState extends ConsumerState<StaffAmountEntryScreen> {
  String _raw = '';
  String? _pressedKey;

  double get _value {
    if (_raw.isEmpty || _raw == '.') return 0;
    return double.tryParse(_raw) ?? 0;
  }

  void _setQuick(double v) {
    HapticFeedback.lightImpact();
    staffHaptic();
    setState(() {
      _raw = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    });
    ref.read(staffEntryAmountProvider.notifier).setAmount(v);
  }

  void _append(String ch) {
    HapticFeedback.lightImpact();
    staffHaptic();
    setState(() {
      if (ch == '.') {
        if (_raw.contains('.')) return;
        _raw = _raw.isEmpty ? '0.' : '$_raw.';
        return;
      }
      final next = _raw + ch;
      final parts = next.split('.');
      if (parts.length == 2 && parts[1].length > 2) return;
      if (next.startsWith('0') &&
          !next.startsWith('0.') &&
          next.length > 1 &&
          !next.startsWith('00.')) {
        return;
      }
      _raw = next;
    });
    ref.read(staffEntryAmountProvider.notifier).setAmount(_value);
  }

  void _bs() {
    HapticFeedback.lightImpact();
    staffHaptic();
    setState(() {
      if (_raw.isEmpty) return;
      _raw = _raw.substring(0, _raw.length - 1);
    });
    ref.read(staffEntryAmountProvider.notifier).setAmount(_value);
  }

  bool _quickSelected(double n) {
    if (_raw.isEmpty) return false;
    final v = double.tryParse(_raw);
    if (v == null) return false;
    if ((v - n).abs() > 0.001) return false;
    final expect =
        n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
    return _raw == expect || _raw == n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(staffTxnModeProvider);
    final c = ref.watch(staffCustomerProvider);
    if (mode == null || c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(staffShellScannerPathForRef(ref));
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final purchase = mode == StaffTxnMode.purchase;
    final title = purchase ? l10n.recordPurchase : l10n.redeemBalance;
    final totalBal = c.totalWalletBalance;
    final over = !purchase && _value > totalBal + 0.001;
    final cbPreview = _value * 0.20;
    const quickAmounts = [10.0, 20.0, 30.0, 50.0, 100.0, 150.0, 200.0];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            staffHaptic();
            context.pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              c.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      l10n.staffAmountSar(_value.toStringAsFixed(2)),
                      key: ValueKey<String>(_raw.isEmpty ? '0' : _raw),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: purchase ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.staffSaudiRiyal,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (!purchase) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.staffAvailableSar(totalBal.toStringAsFixed(2)),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: purchase && _value > 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.goldTint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.staffCashbackPreviewPlus(cbPreview.toStringAsFixed(2)),
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickAmounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final n = quickAmounts[i];
                  final sel = _quickSelected(n);
                  return GestureDetector(
                    onTap: () => _setQuick(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: sel ? AppColors.cardShadow : null,
                      ),
                      child: Center(
                        child: Text(
                          '${n.round()}',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _numPad()),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                style: over
                    ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                    : null,
                onPressed: (_value <= 0 || over)
                    ? null
                    : () {
                        staffHaptic();
                        ref.read(staffEntryAmountProvider.notifier).setAmount(_value);
                        context.push('/staff/confirm');
                      },
                child: Text(
                  over ? l10n.insufficientBalance : l10n.next,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numPad() {
    final keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '.', '0', 'back',
    ];
    return GridView.builder(
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (ctx, i) {
        final k = keys[i];
        final pressed = _pressedKey == k;
        if (k == 'back') {
          return GestureDetector(
            onTapDown: (_) => setState(() => _pressedKey = k),
            onTapUp: (_) => setState(() => _pressedKey = null),
            onTapCancel: () => setState(() => _pressedKey = null),
            onTap: _bs,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: pressed ? AppColors.primaryTint : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Icon(
                  Icons.backspace_outlined,
                  size: 28,
                  color: AppColors.error,
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          onTapDown: (_) => setState(() => _pressedKey = k),
          onTapUp: (_) => setState(() => _pressedKey = null),
          onTapCancel: () => setState(() => _pressedKey = null),
          onTap: () => _append(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: pressed ? AppColors.primaryTint : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                k,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
