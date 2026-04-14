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
  late AnimationController _ring;
  late AnimationController _check;
  late AnimationController _navBar;
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
    _navBar = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
        _navBar.value = 0;
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) _goScanner();
        });
        return;
      }
      unawaited(_ring.forward());
      unawaited(_navBar.forward().then((_) {
        if (mounted) _goScanner();
      }));
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
    _navBar.dispose();
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
    final l10n = AppLocalizations.of(context)!;
    final p = widget.payload;
    final r = p.response;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.successTint,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: disableAnim
                        ? CustomPaint(
                            painter: _SuccessRingPainter(
                              ringT: 1,
                              checkT: 1,
                              strokeColor: AppColors.primary,
                            ),
                          )
                        : AnimatedBuilder(
                            animation: Listenable.merge([_ring, _check]),
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _SuccessRingPainter(
                                  ringT: _ring.value,
                                  checkT: _check.value,
                                  strokeColor: AppColors.primary,
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.staffTransactionCompleted,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.smsSent,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _summaryCard(context, p, r),
                    ),
                  ),
                  if (_undoVisible && p.transactionId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (_undoBusy)
                      const CircularProgressIndicator(color: AppColors.primary)
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _undo,
                            child: Text(
                              l10n.staffUndoShort,
                              style: GoogleFonts.cairo(
                                color: AppColors.error,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _undoSec / 30,
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                  backgroundColor: AppColors.errorTint,
                                ),
                                Text(
                                  '$_undoSec',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: disableAnim
                ? const SizedBox(height: 4)
                : AnimatedBuilder(
                    animation: _navBar,
                    builder: (context, _) {
                      return LinearProgressIndicator(
                        value: 1 - _navBar.value,
                        minHeight: 4,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      );
                    },
                  ),
          ),
        ],
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
