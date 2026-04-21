import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
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

  static const Color _kBlue = Color(0xFF185FA5);
  static const Color _kGreen = Color(0xFF1D9E75);

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
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _topSuccessHeader(disableAnim: disableAnim),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _summaryCard(context, p, r),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_undoVisible && p.transactionId.isNotEmpty) ...[
                    if (_undoBusy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          height: 46,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      )
                    else
                      _undoButton(l10n),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _goScanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'تم',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
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
                        backgroundColor: const Color(0xFFEAEAEA),
                        color: _kBlue,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topSuccessHeader({required bool disableAnim}) {
    final ring = disableAnim
        ? CustomPaint(
            painter: _SuccessRingPainter(
              ringT: 1,
              checkT: 1,
              strokeColor: Colors.white,
            ),
          )
        : AnimatedBuilder(
            animation: Listenable.merge([_ring, _check]),
            builder: (context, _) {
              return CustomPaint(
                painter: _SuccessRingPainter(
                  ringT: _ring.value,
                  checkT: _check.value,
                  strokeColor: Colors.white,
                ),
              );
            },
          );

    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: _kGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kGreen.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: ring,
        ),
        const SizedBox(height: 16),
        Text(
          'تمت العملية بنجاح!',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'تم إرسال SMS للعميل',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8A8A8A),
          ),
        ),
      ],
    );
  }

  Widget _undoButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _undo,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: AppColors.error,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.staffUndoShort,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _undoSec / 30,
                    strokeWidth: 2.5,
                    color: AppColors.error,
                    backgroundColor: AppColors.errorTint,
                  ),
                  Text(
                    '$_undoSec',
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, StaffSuccessPayload p, Map<String, dynamic> r) {
    final c = p.customer;

    String formatSar(double v) => '${v.toStringAsFixed(2)} ${AppLocalizations.of(context)!.currencyDisplay}';

    final paid = p.amount;
    final cbAdded = p.mode == StaffTxnMode.purchase
        ? _d(r['cashback_earned'])
        : (p.mode == StaffTxnMode.subscription ? _d(r['credit_applied']) : 0.0);
    final balance = switch (p.mode) {
      StaffTxnMode.purchase => _d(r['new_cashback_balance']),
      StaffTxnMode.redeem => _d(r['new_subscription_balance']) + _d(r['new_cashback_balance']),
      StaffTxnMode.subscription => _d(r['new_subscription_balance']),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('العميل', c.name),
          const Divider(height: 18),
          _kv('المبلغ المدفوع', formatSar(paid)),
          const Divider(height: 18),
          _kv(
            'الكاش باك المضاف',
            '+${formatSar(cbAdded)}',
            valueColor: _kGreen,
          ),
          const Divider(height: 18),
          _kv(
            'الرصيد الحالي',
            formatSar(balance),
            valueColor: _kBlue,
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7A7A7A),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: valueColor ?? const Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}
