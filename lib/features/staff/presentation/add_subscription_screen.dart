import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/staff/staff_offline_queue.dart';
import '../../../core/staff/staff_pending_tx.dart';
import '../../../core/utils/offline_pending_provider.dart';
import '../../../shared/models/subscription_plan_model.dart';
import '../../customer/presentation/providers/customer_providers.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

const _kIdempotencyPref = 'staff_last_idempotency';

double parseStaffDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _transactionIdFromResponse(Map<String, dynamic> r) {
  final t = r['transaction'];
  if (t is Map && t['id'] != null) return '${t['id']}';
  return '';
}

class StaffAddSubscriptionScreen extends ConsumerStatefulWidget {
  const StaffAddSubscriptionScreen({super.key});

  @override
  ConsumerState<StaffAddSubscriptionScreen> createState() =>
      _StaffAddSubscriptionScreenState();
}

class _StaffAddSubscriptionScreenState
    extends ConsumerState<StaffAddSubscriptionScreen> {
  bool _loading = false;
  String? _error;

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

  void _resetCustomerOnly() {
    ref.read(staffSelectedPlanIdProvider.notifier).setSelectedPlanId(null);
    ref.read(staffCustomerProvider.notifier).select(null);
  }

  Future<void> _confirm() async {
    staffHaptic();
    final c = ref.read(staffCustomerProvider);
    final staff = ref.read(staffMemberProvider).value;
    final planId = ref.read(staffSelectedPlanIdProvider);
    if (c == null || staff == null || planId == null) return;

    final plans = ref.read(subscriptionPlansProvider).value;
    SubscriptionPlanModel? plan;
    if (plans != null) {
      for (final p in plans) {
        if (p.id == planId) {
          plan = p;
          break;
        }
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final key =
        '${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await _persistId(key);
      final connected = await _online();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!connected) {
        await StaffOfflineQueue.instance.enqueue(
          StaffPendingTx(
            kind: 'add_subscription',
            idempotencyKey: key,
            customerId: c.id,
            staffId: staff.id,
            planId: planId,
            createdAtMillis: now,
          ),
        );
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
        _resetCustomerOnly();
        ref.read(staffEntryAmountProvider.notifier).setAmount(0);
        ref.read(staffTxnModeProvider.notifier).setMode(null);
        context.go(staffShellScannerPathForRef(ref));
        await _clearId();
        return;
      }

      final res = await ref.read(staffRepositoryProvider).addSubscription(
            customerId: c.id,
            staffId: staff.id,
            planId: planId,
            idempotencyKey: key,
          );

      await _clearId();
      if (!mounted) return;
      staffSuccessSound();
      staffHaptic();
      final txId = _transactionIdFromResponse(res);
      double price = plan?.price ?? 0;
      if (price <= 0) {
        final t = res['transaction'];
        if (t is Map && t['amount'] != null) {
          price = parseStaffDouble(t['amount']);
        }
      }

      final payload = StaffSuccessPayload(
        transactionId: txId,
        mode: StaffTxnMode.subscription,
        response: res,
        customer: c,
        amount: price,
      );

      ref.read(staffSelectedPlanIdProvider.notifier).setSelectedPlanId(null);
      ref.read(staffTxnModeProvider.notifier).setMode(null);
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
    final l10n = AppLocalizations.of(context)!;
    final c = ref.watch(staffCustomerProvider);
    final selectedId = ref.watch(staffSelectedPlanIdProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);

    if (c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(staffShellScannerPathForRef(ref));
      });
      // Don't show an intermediate "spinner page" while redirecting.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Stack(
      children: [
        Scaffold(
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
                Text(l10n.addSubscription),
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
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.staffSubscriptionBalanceLine(
                      '${c.subscriptionBalance.toStringAsFixed(2)} ${l10n.currencyDisplay}',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              plansAsync.when(
                data: (plans) {
                  return Column(
                    children: plans.map((p) {
                      final sel = p.id == selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: sel
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          elevation: 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              staffHaptic();
                              ref
                                  .read(staffSelectedPlanIdProvider.notifier)
                                  .setSelectedPlanId(p.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.nameAr,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (p.bonusPercentage != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '+${p.bonusPercentage!.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.staffPlanCustomerPaysCash(
                                      '${p.price.toStringAsFixed(2)} ${l10n.currencyDisplay}',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    l10n.staffPlanCustomerGetsCredit(
                                      '${p.credit.toStringAsFixed(2)} ${l10n.currencyDisplay}',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF57C00), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.confirmCashReceived,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (selectedId == null || _loading) ? null : _confirm,
                  child: Text(
                    l10n.staffConfirmAddSubscription,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          const ColoredBox(
            color: Color(0x88000000),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
