import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

class StaffAmountEntryScreen extends ConsumerStatefulWidget {
  const StaffAmountEntryScreen({super.key});

  @override
  ConsumerState<StaffAmountEntryScreen> createState() =>
      _StaffAmountEntryScreenState();
}

class _StaffAmountEntryScreenState extends ConsumerState<StaffAmountEntryScreen> {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);
  static const _kAmber = Color(0xFFEF9F27);

  String _raw = '';
  String? _pressedKey;

  double get _value {
    if (_raw.isEmpty || _raw == '.') return 0;
    return double.tryParse(_raw) ?? 0;
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
    final title = switch (mode) {
      StaffTxnMode.purchase => 'شراء',
      StaffTxnMode.redeem => 'استرداد',
      StaffTxnMode.subscription => 'باقة',
    };
    final totalBal = c.totalWalletBalance;
    final over = mode == StaffTxnMode.redeem && _value > totalBal + 0.001;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            staffHaptic();
            context.pop();
          },
        ),
        backgroundColor: _kPageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _OpBadge(mode: mode, title: title),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                c.name,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Text(
                    '${_value.toStringAsFixed(2)} ر.س',
                    key: ValueKey<String>(_raw.isEmpty ? '0' : _raw),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: _kPointBlue,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<double>(
                    future: _cashbackRate(),
                    builder: (context, snap) {
                      final rate = snap.data ?? 0.20;
                      final cbPreview = _value * rate;
                      return AnimatedOpacity(
                        opacity: purchase ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          'كاش باك سيُضاف: ${cbPreview.toStringAsFixed(2)} ر.س',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: purchase ? _kAmber : const Color(0xFF9CA3AF),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _numPad()),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPointBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPointBlue.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_value <= 0 || over)
                    ? null
                    : () {
                        staffHaptic();
                        ref.read(staffEntryAmountProvider.notifier).setAmount(_value);
                        context.push('/staff/confirm');
                      },
                child: Text(
                  over ? l10n.insufficientBalance : 'تأكيد',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
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

  Future<double> _cashbackRate() async {
    if (!Env.hasSupabase) return 0.20;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 0.20;
    final mem = await Supabase.instance.client
        .from('store_memberships')
        .select('store_id')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    final storeId = mem?['store_id'] as String?;
    if (storeId == null) return 0.20;
    final store = await Supabase.instance.client
        .from('stores')
        .select('cashback_rate')
        .eq('id', storeId)
        .maybeSingle();
    final r = store?['cashback_rate'];
    if (r is num) return r.toDouble();
    return double.tryParse('$r') ?? 0.20;
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
        mainAxisExtent: 72,
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
                color: pressed ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Icon(
                  Icons.backspace_outlined,
                  size: 28,
                  color: Color(0xFFEF4444),
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
              color: pressed ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Center(
              child: Text(
                k,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OpBadge extends StatelessWidget {
  const _OpBadge({required this.mode, required this.title});

  final StaffTxnMode mode;
  final String title;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (mode) {
      StaffTxnMode.purchase => (const Color(0xFFEFF6FF), const Color(0xFF185FA5)),
      StaffTxnMode.redeem => (const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
      StaffTxnMode.subscription => (const Color(0xFFEEEDFE), const Color(0xFF3C3489)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        title,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900),
      ),
    );
  }
}
