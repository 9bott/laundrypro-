import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/offline_pending_provider.dart';
import '../../customer/presentation/providers/customer_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/blue_button.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';

const Color _scanPrimary = Color(0xFF2563EB);

/// تنظيف ناتج الكاميرا — JWT = نقطة + نقطة؛ نأخذ أول 3 مقاطع كاملة (بدون regex خاطئ لـ `-` داخل `[]`).
String normalizeScannedQrToken(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  s = s.replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014]'), '-');

  final param = RegExp(
    r'(?:^|[?&#])(?:token|qr_token|access_token)=([^&#\s]+)',
    caseSensitive: false,
  ).firstMatch(s);
  if (param != null) {
    try {
      s = Uri.decodeQueryComponent(param.group(1)!);
    } catch (_) {
      s = param.group(1)!;
    }
  }

  final ey = s.indexOf('eyJ');
  if (ey >= 0) s = s.substring(ey);

  final parts = s.split('.');
  if (parts.length >= 3) {
    var a = parts[0].trim();
    var b = parts[1].trim();
    var c = parts[2].trim();
    for (final stop in [' ', '\n', '\r', '\t', '"', ',', ')', ']', '}']) {
      final i = c.indexOf(stop);
      if (i > 0) c = c.substring(0, i);
    }
    return '$a.$b.$c';
  }

  return s.trim();
}

/// قيم لجرّة الاستدعاء: مُطبَّع ثم نص أنظف ثم الخام.
Iterable<String> qrTokenCandidates(String raw) sync* {
  final n = normalizeScannedQrToken(raw);
  if (n.isNotEmpty) yield n;

  var plain = raw.trim();
  plain = plain.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (plain.isNotEmpty && plain != n) yield plain;

  final t = raw.trim();
  if (t.isNotEmpty && t != n && t != plain) yield t;
}

class StaffScannerScreen extends ConsumerStatefulWidget {
  const StaffScannerScreen({super.key});

  @override
  ConsumerState<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends ConsumerState<StaffScannerScreen>
    with TickerProviderStateMixin {
  late final MobileScannerController _cam;
  late AnimationController _scanSweep;
  ProviderSubscription<AsyncValue<bool>>? _connSub;
  String? _scanMsg;
  bool _handling = false;
  String? _lastCode;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    _cam = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _scanSweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connSub ??= staffListenConnectivityDrainManual(ref);
      unawaited(() async {
        await ref.read(staffOfflineSyncProvider).processAll();
        if (mounted) bumpOfflinePendingBadge(ref);
      }());
    });
  }

  @override
  void dispose() {
    _connSub?.close();
    _scanSweep.dispose();
    _cam.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLoginModePrefKey);
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    context.go('/auth/phone');
  }

  void _clearScanMsg() {
    if (_scanMsg != null) {
      setState(() => _scanMsg = null);
    }
  }

  Future<void> _onQr(String raw) async {
    final now = DateTime.now();
    if (_lastCode == raw &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastCode = raw;
    _lastAt = now;

    if (_handling) return;
    _handling = true;
    try {
      final repo = ref.read(staffRepositoryProvider);
      final candidates = qrTokenCandidates(raw).toList();
      StaffApiException? lastErr;
      for (var i = 0; i < candidates.length; i++) {
        final token = candidates[i];
        try {
          final c = await repo.getCustomerByQr(token);
          if (!mounted) return;
          staffSuccessSound();
          staffHaptic();
          ref.read(staffCustomerProvider.notifier).select(c);
          context.go('/staff/customer-card');
          return;
        } on StaffApiException catch (e) {
          lastErr = e;
          final canRetry = e.status == 400 &&
              e.code == 'qr_invalid' &&
              i < candidates.length - 1;
          if (canRetry) continue;
          break;
        }
      }
      final e = lastErr;
      if (e == null) return;
      throw e;
    } on StaffApiException catch (e) {
      debugPrint(
        '[StaffScanner] getCustomerByQr failed: status=${e.status} code=${e.code} message=${e.message}',
      );
      if (!mounted) return;
      staffHaptic();
      if (e.isQrExpired) {
        setState(() {
          _scanMsg = 'رمز QR منتهي الصلاحية - اطلب من العميل تحديثه';
        });
        Future.delayed(const Duration(seconds: 4), _clearScanMsg);
      } else if (e.code == 'qr_invalid' ||
          e.message.toLowerCase().contains('qr_invalid') ||
          e.message.toLowerCase().contains('invalid qr')) {
        final detail =
            e.message.isNotEmpty && e.message != 'qr_invalid' ? '\n${e.message}' : '';
        setState(() => _scanMsg = 'رمز QR غير صالح$detail');
        Future.delayed(const Duration(seconds: 6), _clearScanMsg);
      } else if (e.code == 'network_error') {
        setState(() => _scanMsg = e.message);
        Future.delayed(const Duration(seconds: 4), _clearScanMsg);
      } else {
        setState(() => _scanMsg = e.message);
        Future.delayed(const Duration(seconds: 4), _clearScanMsg);
      }
    } catch (e) {
      debugPrint('[StaffScanner] unexpected error: $e');
      if (!mounted) return;
      setState(() => _scanMsg = '$e');
      Future.delayed(const Duration(seconds: 4), _clearScanMsg);
    } finally {
      _handling = false;
    }
  }

  void _openPhoneSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PhoneLookupSheet(),
    );
  }

  static Rect _frameRect(Size size) {
    final w = size.width * 0.72;
    final h = w;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2 - 24;
    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final staffAsync = ref.watch(staffMemberProvider);
    final staff = staffAsync.value;
    final name = staff?.name ?? '';
    final role = (staff?.role ?? 'staff').toLowerCase();
    final isMgr = role == 'owner' || role == 'manager';
    final pending = ref.watch(offlinePendingCountProvider);
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shadow: const [],
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.logout_outlined, color: AppColors.primary, size: 22),
                      onPressed: _logout,
                    ),
                    if (pending > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 4, right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: l10n.pendingOfflineTooltip,
                              child: Icon(Icons.cloud_sync_outlined, color: AppColors.warning, size: 18),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.welcomeUser(name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMgr ? AppColors.goldTint : AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isMgr ? AppColors.gold.withOpacity(0.35) : AppColors.primaryBorder,
                              ),
                            ),
                            child: Text(
                              isMgr ? l10n.roleManager : l10n.roleStaffMember,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isMgr ? AppColors.gold : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _cam,
                    onDetect: (capture) {
                      for (final b in capture.barcodes) {
                        final v = b.rawValue;
                        if (v != null && v.isNotEmpty) {
                          unawaited(_onQr(v));
                          break;
                        }
                      }
                    },
                  ),
                  IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return CustomPaint(
                          size: Size(c.maxWidth, c.maxHeight),
                          painter: _HoleMaskPainter(
                            frame: _frameRect(Size(c.maxWidth, c.maxHeight)),
                          ),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return CustomPaint(
                          size: Size(c.maxWidth, c.maxHeight),
                          painter: _CornerBracketsPainter(
                            frame: _frameRect(Size(c.maxWidth, c.maxHeight)),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!disableAnim)
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _scanSweep,
                        builder: (context, c) {
                          return LayoutBuilder(
                            builder: (context, cons) {
                              return CustomPaint(
                                size: Size(cons.maxWidth, cons.maxHeight),
                                painter: _ScanLinePainter(
                                  t: _scanSweep.value,
                                  frame: _frameRect(Size(cons.maxWidth, cons.maxHeight)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 100,
                    child: Text(
                      l10n.staffScanCustomerQr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.85),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_scanMsg != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Material(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              _scanMsg!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _openPhoneSheet(context),
                icon: const Icon(Icons.phone_outlined, size: 22),
                label: Text(
                  l10n.staffSearchByPhone,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoleMaskPainter extends CustomPainter {
  _HoleMaskPainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(16)),
      );
    final hole = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      hole,
      Paint()..color = Colors.black.withOpacity(0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _HoleMaskPainter oldDelegate) => oldDelegate.frame != frame;
}

class _CornerBracketsPainter extends CustomPainter {
  _CornerBracketsPainter({required this.frame});

  final Rect frame;
  static const double _corner = 40;
  static const double _stroke = 3;
  static const double _r = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _scanPrimary
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void lTopLeft() {
      final path = Path()
        ..moveTo(frame.left, frame.top + _corner)
        ..lineTo(frame.left, frame.top + _r)
        ..quadraticBezierTo(frame.left, frame.top, frame.left + _r, frame.top)
        ..lineTo(frame.left + _corner, frame.top);
      canvas.drawPath(path, paint);
    }

    void lTopRight() {
      final path = Path()
        ..moveTo(frame.right - _corner, frame.top)
        ..lineTo(frame.right - _r, frame.top)
        ..quadraticBezierTo(frame.right, frame.top, frame.right, frame.top + _r)
        ..lineTo(frame.right, frame.top + _corner);
      canvas.drawPath(path, paint);
    }

    void lBottomLeft() {
      final path = Path()
        ..moveTo(frame.left, frame.bottom - _corner)
        ..lineTo(frame.left, frame.bottom - _r)
        ..quadraticBezierTo(frame.left, frame.bottom, frame.left + _r, frame.bottom)
        ..lineTo(frame.left + _corner, frame.bottom);
      canvas.drawPath(path, paint);
    }

    void lBottomRight() {
      final path = Path()
        ..moveTo(frame.right - _corner, frame.bottom)
        ..lineTo(frame.right - _r, frame.bottom)
        ..quadraticBezierTo(frame.right, frame.bottom, frame.right, frame.bottom - _r)
        ..lineTo(frame.right, frame.bottom - _corner);
      canvas.drawPath(path, paint);
    }

    lTopLeft();
    lTopRight();
    lBottomLeft();
    lBottomRight();
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => oldDelegate.frame != frame;
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({required this.t, required this.frame});

  final double t;
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final lineWidth = frame.width * 0.8;
    final left = frame.left + (frame.width - lineWidth) / 2;
    final y = frame.top + 8 + (frame.height - 16) * t;
    final grad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          _scanPrimary.withOpacity(0.95),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(left, y - 1, lineWidth, 2));
    canvas.drawRect(Rect.fromLTWH(left, y - 1, lineWidth, 2), grad);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.frame != frame;
}

class _PhoneLookupSheet extends ConsumerStatefulWidget {
  const _PhoneLookupSheet();

  @override
  ConsumerState<_PhoneLookupSheet> createState() => _PhoneLookupSheetState();
}

class _PhoneLookupSheetState extends ConsumerState<_PhoneLookupSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  List<StaffCustomerView> _results = [];
  String? _err;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String? _toE164(String nine) {
    final d = nine.replaceAll(RegExp(r'\D'), '');
    if (d.length == 9) return '+966$d';
    if (d.length == 12 && d.startsWith('966')) return '+$d';
    return null;
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context)!;
    final e164 = _toE164(_ctrl.text);
    if (e164 == null) {
      setState(() => _err = l10n.staffEnterNineDigits);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _results = [];
    });
    try {
      final list =
          await ref.read(staffRepositoryProvider).getCustomerByPhone(e164);
      if (!mounted) return;
      setState(() {
        _results = list;
        if (list.isEmpty) {
          _err = l10n.staffNoCustomerForPhone;
        }
      });
      if (list.length == 1) {
        staffSuccessSound();
        staffHaptic();
        ref.read(staffCustomerProvider.notifier).select(list.single);
        Navigator.pop(context);
        context.go('/staff/customer-card');
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.staffFindCustomer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ctrl,
                focusNode: _focus,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: l10n.mobilePhone,
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixText: '+966 ',
                  prefixStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  hintText: '5XXXXXXXX',
                  hintStyle: TextStyle(color: AppColors.textHint.withOpacity(0.9)),
                ),
                onFieldSubmitted: (_) {
                  HapticFeedback.lightImpact();
                  unawaited(_search());
                },
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(_err!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 12),
              BlueButton(
                label: l10n.search,
                loading: _busy,
                onTap: _busy ? null : _search,
              ),
              if (_results.length > 1) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.staffPickCustomer,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _results.map((c) {
                    return ActionChip(
                      label: Text(c.name, style: const TextStyle(fontSize: 16)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        staffSuccessSound();
                        ref.read(staffCustomerProvider.notifier).select(c);
                        Navigator.pop(context);
                        context.go('/staff/customer-card');
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
