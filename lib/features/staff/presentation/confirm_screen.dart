import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/staff/staff_offline_queue.dart';
import '../../../core/staff/staff_pending_tx.dart';
import '../../../core/utils/offline_pending_provider.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

const _kIdempotencyPref = 'staff_last_idempotency';

({double sub, double cb}) _redeemSplit(double amount, StaffCustomerView c) {
  final subCap = c.subscriptionBalance;
  final cbCap = c.cashbackBalance;
  final subUsed = amount <= subCap ? amount : subCap;
  final rem = amount - subUsed;
  final cbUsed = rem <= 0 ? 0.0 : (rem <= cbCap ? rem : cbCap);
  return (sub: subUsed, cb: cbUsed);
}

String _transactionIdFromResponse(Map<String, dynamic> r) {
  final t = r['transaction'];
  if (t is Map && t['id'] != null) return '${t['id']}';
  if (r['transaction_id'] != null) return '${r['transaction_id']}';
  return '';
}

class StaffConfirmScreen extends ConsumerStatefulWidget {
  const StaffConfirmScreen({super.key});

  @override
  ConsumerState<StaffConfirmScreen> createState() => _StaffConfirmScreenState();
}

class _StaffConfirmScreenState extends ConsumerState<StaffConfirmScreen>
    with SingleTickerProviderStateMixin {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);

  bool _loading = false;
  String? _error;

  late AnimationController _markAnim;

  @override
  void initState() {
    super.initState();
    _markAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _markAnim.value = 1;
      } else {
        _markAnim.forward();
      }
    });
  }

  @override
  void dispose() {
    _markAnim.dispose();
    super.dispose();
  }

  Future<void> _persistId(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kIdempotencyPref, key);
  }

  Future<void> _clearId() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kIdempotencyPref);
  }

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((e) => e != ConnectivityResult.none);
  }

  void _resetFlow() {
    ref.read(staffCustomerProvider.notifier).select(null);
    ref.read(staffEntryAmountProvider.notifier).setAmount(0);
    ref.read(staffTxnModeProvider.notifier).setMode(null);
  }

  Future<void> _confirm() async {
    HapticFeedback.lightImpact();
    final mode = ref.read(staffTxnModeProvider);
    final c = ref.read(staffCustomerProvider);
    final staff = ref.read(staffMemberProvider).value;
    final amount = ref.read(staffEntryAmountProvider);
    if (mode == null || c == null || staff == null || amount <= 0) return;

    final purchase = mode == StaffTxnMode.purchase;
    final key =
        '${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _persistId(key);

      final connected = await _online();
      if (!connected) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (purchase) {
          await StaffOfflineQueue.instance.enqueue(
            StaffPendingTx(
              kind: 'add_purchase',
              idempotencyKey: key,
              customerId: c.id,
              staffId: staff.id,
              amount: amount,
              createdAtMillis: now,
            ),
          );
        } else {
          await StaffOfflineQueue.instance.enqueue(
            StaffPendingTx(
              kind: 'redeem_balance',
              idempotencyKey: key,
              customerId: c.id,
              staffId: staff.id,
              amount: amount,
              createdAtMillis: now,
            ),
          );
        }
        if (!mounted) return;
        staffSuccessSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.staffOfflineTxSaved,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        bumpOfflinePendingBadge(ref);
        _resetFlow();
        context.go(staffShellScannerPathForRef(ref));
        await _clearId();
        return;
      }

      final repo = ref.read(staffRepositoryProvider);
      Map<String, dynamic> res;
      if (purchase) {
        res = await repo.addPurchase(
          customerId: c.id,
          staffId: staff.id,
          storeId: staff.storeId,
          amount: amount,
          idempotencyKey: key,
        );
      } else {
        res = await repo.redeemBalance(
          customerId: c.id,
          staffId: staff.id,
          storeId: staff.storeId,
          amount: amount,
          idempotencyKey: key,
        );
      }

      await _clearId();
      if (!mounted) return;
      staffSuccessSound();
      HapticFeedback.mediumImpact();
      final txId = _transactionIdFromResponse(res);
      final split = _redeemSplit(amount, c);
      final payload = StaffSuccessPayload(
        transactionId: txId,
        mode: mode,
        response: res,
        customer: c,
        amount: amount,
        subscriptionUsed: purchase ? null : split.sub,
        cashbackUsed: purchase ? null : split.cb,
      );
      context.go('/staff/success', extra: payload);
    } on StaffApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(staffTxnModeProvider);
    final c = ref.watch(staffCustomerProvider);
    final amount = ref.watch(staffEntryAmountProvider);
    if (mode == null || c == null || amount <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(staffShellScannerPathForRef(ref));
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final purchase = mode == StaffTxnMode.purchase;
    final split = _redeemSplit(amount, c);
    final badge = switch (mode) {
      StaffTxnMode.purchase => ('شراء', const Color(0xFFEFF6FF), _kPointBlue),
      StaffTxnMode.redeem => ('استرداد', const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
      StaffTxnMode.subscription => ('باقة', const Color(0xFFEEEDFE), const Color(0xFF3C3489)),
    };

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _kPageBg,
          appBar: AppBar(
            title: const Text('تأكيد العملية', style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: _kPageBg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _loading ? null : () => context.pop(),
            ),
          ),
          body: FutureBuilder<double>(
            future: _cashbackRate(),
            builder: (context, snap) {
              final rate = snap.data ?? 0.20;
              final cbAdd = amount * rate;
              final afterCb = c.cashbackBalance + cbAdd;
              final totalAfterRedeem = c.totalWalletBalance - amount;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: badge.$2,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: badge.$3.withValues(alpha: 0.18)),
                            ),
                            child: Text(
                              badge.$1,
                              style: TextStyle(color: badge.$3, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),
                        _kv('العميل', c.name, bold: true),
                        _kv('المبلغ', '${amount.toStringAsFixed(2)} ر.س', bold: true, valueColor: _kPointBlue),
                        if (purchase)
                          _kv('كاش باك مضاف', '+${cbAdd.toStringAsFixed(2)} ر.س', bold: true, valueColor: AppColors.success),
                        if (!purchase)
                          _kv('سيُخصم من', split.sub > 0 ? 'رصيد الاشتراك + كاش باك' : 'كاش باك', bold: true),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _kv('الرصيد الحالي', '${c.totalWalletBalance.toStringAsFixed(2)} ر.س'),
                        _kv(
                          'الرصيد بعد العملية',
                          purchase ? '${(c.totalWalletBalance + cbAdd).toStringAsFixed(2)} ر.س' : '${totalAfterRedeem.toStringAsFixed(2)} ر.س',
                          valueColor: purchase ? AppColors.success : (totalAfterRedeem <= 5 ? AppColors.error : AppColors.success),
                          bold: true,
                        ),
                        if (purchase) ...[
                          const SizedBox(height: 6),
                          _kv('كاش باك بعد العملية', '${afterCb.toStringAsFixed(2)} ر.س'),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _loading ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPointBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('تأكيد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _resetFlow();
                              context.go(staffShellScannerPathForRef(ref));
                            },
                      child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (_loading)
          const ColoredBox(
            color: Color(0x55000000),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Future<double> _cashbackRate() async {
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

  Widget _kv(String k, String v, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            v,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF111827),
              fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
