import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';
import 'staff_route_models.dart';

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

class _SuccessRingPainter extends CustomPainter {
  _SuccessRingPainter({
    required this.ringT,
    required this.checkT,
    this.strokeColor = Colors.white,
  });

  /// 0..1 arc sweep for the ring (1.5s animation).
  final double ringT;

  /// 0..1 checkmark draw progress.
  final double checkT;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    final ringPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final sweep = ringT * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      ringPaint,
    );

    if (checkT <= 0) return;

    final path = Path()
      ..moveTo(c.dx - r * 0.34, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.08, c.dy + r * 0.28)
      ..lineTo(c.dx + r * 0.38, c.dy - r * 0.26);

    for (final m in path.computeMetrics()) {
      final extract = m.extractPath(0, m.length * checkT);
      canvas.drawPath(
        extract,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessRingPainter oldDelegate) {
    return oldDelegate.ringT != ringT ||
        oldDelegate.checkT != checkT ||
        oldDelegate.strokeColor != strokeColor;
  }
}

class StaffSuccessScreen extends ConsumerStatefulWidget {
  const StaffSuccessScreen({super.key, required this.payload});

  final StaffSuccessPayload payload;

  @override
  ConsumerState<StaffSuccessScreen> createState() => _StaffSuccessScreenState();
}

class _StaffSuccessScreenState extends ConsumerState<StaffSuccessScreen>
    with TickerProviderStateMixin {
  static const _kPageBg = Color(0xFFF8F9FA);
  static const _kPointBlue = Color(0xFF185FA5);
  static const _kGreenText = Color(0xFF085041);
  static const _kAmberBorder = Color(0xFFEF9F27);

  late AnimationController _ring;
  late AnimationController _check;
  late AnimationController _scale;
  Timer? _undoTimer;
  int _undoSec = 30;
  bool _undoVisible = true;
  bool _undoBusy = false;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _check = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ring.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _check.forward();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _ring.value = 1;
        _check.value = 1;
        _scale.value = 1;
        return;
      }
      unawaited(_scale.forward());
      unawaited(_ring.forward());
    });

    _undoSec = 30;
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_undoSec <= 1) {
        t.cancel();
        setState(() => _undoVisible = false);
      } else {
        setState(() => _undoSec--);
      }
    });
  }

  void _goScanner() {
    ref.read(staffCustomerProvider.notifier).select(null);
    ref.read(staffEntryAmountProvider.notifier).setAmount(0);
    ref.read(staffTxnModeProvider.notifier).setMode(null);
    if (mounted) context.go(staffShellScannerPathForRef(ref));
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _ring.dispose();
    _check.dispose();
    _scale.dispose();
    super.dispose();
  }

  Future<void> _undo() async {
    final id = widget.payload.transactionId;
    if (id.isEmpty) return;
    final staff = ref.read(staffMemberProvider).value;
    if (staff == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final d = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(d.staffUndoDialogTitle),
          content: Text(d.staffUndoDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(d.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(d.staffConfirmUndo),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    staffHaptic();
    setState(() => _undoBusy = true);
    try {
      await ref.read(staffRepositoryProvider).undoTransaction(
            transactionId: id,
            staffId: staff.id,
            storeId: staff.storeId,
          );
      if (!mounted) return;
      staffSuccessSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.staffTransactionUndone)),
      );
      _goScanner();
    } on StaffApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _undoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final r = p.response;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ScaleTransition(
                scale: CurvedAnimation(parent: _scale, curve: Curves.elasticOut),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE1F5EE),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: disableAnim
                          ? CustomPaint(
                              painter: _SuccessRingPainter(
                                ringT: 1,
                                checkT: 1,
                                strokeColor: AppColors.success,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: Listenable.merge([_ring, _check]),
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _SuccessRingPainter(
                                    ringT: _ring.value,
                                    checkT: _check.value,
                                    strokeColor: AppColors.success,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تمت العملية بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kGreenText),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: _summaryCard(context, p, r),
                ),
              ),
              if (_undoVisible && p.transactionId.isNotEmpty) ...[
                const SizedBox(height: 14),
                if (_undoBusy)
                  const CircularProgressIndicator(color: _kPointBlue)
                else
                  SizedBox(
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            value: _undoSec / 30,
                            strokeWidth: 3,
                            color: _kAmberBorder,
                            backgroundColor: _kAmberBorder.withValues(alpha: 0.18),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _undo,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF633806),
                            side: const BorderSide(color: _kAmberBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: Text(
                            'تراجع عن العملية ($_undoSec)',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _goScanner,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPointBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('تم', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, StaffSuccessPayload p, Map<String, dynamic> r) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 3),
          ),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: _summary(context, p, r),
      ),
    );
  }

  Widget _summary(BuildContext context, StaffSuccessPayload p, Map<String, dynamic> r) {
    final l10n = AppLocalizations.of(context)!;
    String amt(double v) => '${v.toStringAsFixed(2)} ${l10n.currencyDisplay}';
    final c = p.customer;
    switch (p.mode) {
      case StaffTxnMode.purchase:
        final paid = p.amount;
        final cb = _d(r['cashback_earned']);
        final newCb = _d(r['new_cashback_balance']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line(l10n.staffSuccCustomer, c.name),
            _line(l10n.staffSuccAmountPaid, amt(paid)),
            _line(l10n.staffSuccCashbackAdded, '+${amt(cb)}',
                color: AppColors.success),
            _line(l10n.staffSuccCashbackNow, amt(newCb)),
          ],
        );
      case StaffTxnMode.redeem:
        final su = _d(r['subscription_used']);
        final cu = _d(r['cashback_used']);
        final ns = _d(r['new_subscription_balance']);
        final nc = _d(r['new_cashback_balance']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line(l10n.staffSuccCustomer, c.name),
            _line(l10n.staffSuccAmountRedeemed, amt(p.amount)),
            _line(l10n.staffSuccFromSubscription, amt(su)),
            _line(l10n.staffSuccFromCashback, amt(cu)),
            _line(l10n.staffSuccSubAfter, amt(ns)),
            _line(l10n.staffSuccCashbackAfter, amt(nc)),
          ],
        );
      case StaffTxnMode.subscription:
        final credit = _d(r['credit_applied']);
        final ns = _d(r['new_subscription_balance']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _line(l10n.staffSuccCustomer, c.name),
            _line(l10n.staffSuccPaidCash, amt(p.amount)),
            _line(l10n.staffSuccCreditAdded, '+${amt(credit)}',
                color: AppColors.success),
            _line(l10n.staffSuccSubNow, amt(ns)),
          ],
        );
    }
  }

  Widget _line(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              k,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            v,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
