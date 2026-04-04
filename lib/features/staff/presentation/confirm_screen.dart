import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/blue_button.dart';
import '../../../shared/widgets/tier_badge.dart';
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
          amount: amount,
          idempotencyKey: key,
        );
      } else {
        res = await repo.redeemBalance(
          customerId: c.id,
          staffId: staff.id,
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

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
    return '${p[0][0]}${p[p.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final mode = ref.watch(staffTxnModeProvider);
    final c = ref.watch(staffCustomerProvider);
    final amount = ref.watch(staffEntryAmountProvider);
    if (mode == null || c == null || amount <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(staffShellScannerPathForRef(ref));
        }
      });
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final purchase = mode == StaffTxnMode.purchase;
    final markColor = purchase ? AppColors.primary : AppColors.warning;
    final cbAdd = amount * 0.20;
    final split = _redeemSplit(amount, c);
    final afterCb = c.cashbackBalance + cbAdd;
    final totalAfterRedeem = c.totalWalletBalance - amount;

    final summaryBorder =
        purchase ? AppColors.primary.withOpacity(0.65) : AppColors.gold.withOpacity(0.65);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
              onPressed: _loading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
            ),
          ),
          body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _markAnim,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(80, 80),
                        painter: _ConfirmMarkPainter(
                          progress: _markAnim.value,
                          color: markColor,
                          pulse: disableAnim ? 1.0 : (0.92 + 0.08 * (0.5 - (_markAnim.value - 0.5).abs() * 2)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.confirmOperation,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              c.name,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TierBadge(
                              tier: c.tier,
                              activePlanName: c.activePlanName,
                              activePlanNameAr: c.activePlanNameAr,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: ClipOval(
                          child: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: c.avatarUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 80,
                                  memCacheHeight: 80,
                                )
                              : Text(
                                  _initials(c.name),
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textOnBlue,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  radius: 18,
                  padding: EdgeInsets.zero,
                  borderColor: summaryBorder,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border(
                        left: BorderSide(color: summaryBorder, width: 4),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: purchase
                        ? _SummaryRowsPurchase(
                            l10n: l10n,
                            amount: amount,
                            cbAdd: cbAdd,
                            afterCb: afterCb,
                          )
                        : _SummaryRowsRedeem(
                            l10n: l10n,
                            amount: amount,
                            split: split,
                            totalAfter: totalAfterRedeem,
                          ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: const BorderDirectional(
                      start: BorderSide(color: AppColors.error, width: 3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: BlueButton(
                  loading: _loading,
                  enabled: !_loading,
                  label: '✓ ${l10n.confirmOperation}',
                  onTap: _loading ? null : _confirm,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _resetFlow();
                          context.go(staffShellScannerPathForRef(ref));
                        },
                  child: Text(
                    l10n.cancel,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SummaryRowsPurchase extends StatelessWidget {
  const _SummaryRowsPurchase({
    required this.l10n,
    required this.amount,
    required this.cbAdd,
    required this.afterCb,
  });

  final AppLocalizations l10n;
  final double amount;
  final double cbAdd;
  final double afterCb;

  String _amt(double v) => '${v.toStringAsFixed(2)} ${l10n.currencyDisplay}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          icon: '💵',
          text: l10n.staffSummaryPurchAmountPaid(_amt(amount)),
          strong: true,
        ),
        const SizedBox(height: 14),
        _SummaryRow(
          icon: '✨',
          text: l10n.staffSummaryPurchCbAdded(_amt(cbAdd)),
          accent: AppColors.gold,
        ),
        const SizedBox(height: 14),
        _SummaryRow(
          icon: '👜',
          text: l10n.staffSummaryPurchCbAfter(_amt(afterCb)),
        ),
      ],
    );
  }
}

class _SummaryRowsRedeem extends StatelessWidget {
  const _SummaryRowsRedeem({
    required this.l10n,
    required this.amount,
    required this.split,
    required this.totalAfter,
  });

  final AppLocalizations l10n;
  final double amount;
  final ({double sub, double cb}) split;
  final double totalAfter;

  String _amt(double v) => '${v.toStringAsFixed(2)} ${l10n.currencyDisplay}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          icon: '💳',
          text: l10n.staffSummaryRedeemAmount(_amt(amount)),
          strong: true,
        ),
        const SizedBox(height: 10),
        _SummaryRow(
          icon: '📦',
          text: l10n.staffSummaryRedeemFromSub(_amt(split.sub)),
        ),
        const SizedBox(height: 6),
        _SummaryRow(
          icon: '💎',
          text: l10n.staffSummaryRedeemFromCb(_amt(split.cb)),
          accent: AppColors.gold,
        ),
        const SizedBox(height: 14),
        _SummaryRow(
          icon: '👜',
          text: l10n.staffSummaryRedeemWalletAfter(_amt(totalAfter)),
          strong: true,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.text,
    this.strong = false,
    this.accent,
  });

  final String icon;
  final String text;
  final bool strong;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryTint,
            border: Border.all(color: AppColors.border.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: (accent ?? AppColors.primary).withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(icon, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: strong ? 15 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: accent ?? AppColors.textPrimary.withOpacity(0.92),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmMarkPainter extends CustomPainter {
  _ConfirmMarkPainter({required this.progress, required this.color, this.pulse = 1.0});

  final double progress;
  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide / 2 - 6) * pulse;
    final glow = Paint()
      ..color = color.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(c, r + 2, glow);

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final ringPhase = (progress / 0.55).clamp(0.0, 1.0);
    final sweep = 2 * 3.141592653589793 * ringPhase;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -3.141592653589793 / 2, sweep, false, ringPaint);

    if (progress < 0.55) return;

    final checkT = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
    final path = Path()
      ..moveTo(c.dx - r * 0.42, c.dy)
      ..lineTo(c.dx - r * 0.08, c.dy + r * 0.32)
      ..lineTo(c.dx + r * 0.45, c.dy - r * 0.34);
    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * checkT);
    canvas.drawPath(
      extract,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfirmMarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.pulse != pulse;
}

