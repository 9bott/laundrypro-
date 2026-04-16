import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/staff/staff_feedback.dart';
import '../../../core/utils/offline_pending_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../customer/presentation/providers/customer_providers.dart';
import '../data/staff_repository.dart';
import 'providers/staff_providers.dart';

const Color _kPageBg = Color(0xFFF8F9FA);
const Color _kPointBlue = Color(0xFF185FA5);

String _initials(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'مت';
  final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return t.characters.take(2).toString();
  if (parts.length == 1) return parts.first.characters.take(2).toString();
  return (parts.first.characters.take(1).toString() +
          parts.last.characters.take(1).toString())
      .toUpperCase();
}

class _StaffStoreView {
  const _StaffStoreView({
    required this.storeName,
    required this.logoUrl,
    required this.role,
  });

  final String storeName;
  final String? logoUrl;
  final String role;
}

final _staffStoreViewProvider = FutureProvider<_StaffStoreView>((ref) async {
  if (!Env.hasSupabase) {
    return const _StaffStoreView(storeName: 'متجري', logoUrl: null, role: 'staff');
  }
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return const _StaffStoreView(storeName: 'متجري', logoUrl: null, role: 'staff');
  }
  final mem = await Supabase.instance.client
      .from('store_memberships')
      .select('role, store_id')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();
  final role = (mem?['role'] as String?)?.toLowerCase() ?? 'staff';
  final storeId = mem?['store_id'] as String?;
  if (storeId == null) {
    return _StaffStoreView(storeName: 'متجري', logoUrl: null, role: role);
  }
  final store = await Supabase.instance.client
      .from('stores')
      .select('name, logo_url')
      .eq('id', storeId)
      .maybeSingle();
  final name = (store?['name'] as String?)?.trim();
  final logo = store?['logo_url'] as String?;
  return _StaffStoreView(
    storeName: (name == null || name.isEmpty) ? 'متجري' : name,
    logoUrl: logo,
    role: role,
  );
});

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
  ProviderSubscription<AsyncValue<bool>>? _connSub;
  String? _scanMsg;
  bool _handling = false;
  String? _lastCode;
  DateTime? _lastAt;

  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _phoneBusy = false;
  List<StaffCustomerView> _phoneResults = [];
  String? _phoneErr;

  @override
  void initState() {
    super.initState();
    _cam = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
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
    _cam.dispose();
    _phoneFocus.dispose();
    _phoneCtrl.dispose();
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

  String? _toE164(String nine) {
    final d = nine.replaceAll(RegExp(r'\D'), '');
    if (d.length == 9) return '+966$d';
    if (d.length == 12 && d.startsWith('966')) return '+$d';
    return null;
  }

  Future<void> _searchByPhone() async {
    final l10n = AppLocalizations.of(context)!;
    final e164 = _toE164(_phoneCtrl.text);
    if (e164 == null) {
      setState(() => _phoneErr = l10n.staffEnterNineDigits);
      return;
    }
    setState(() {
      _phoneBusy = true;
      _phoneErr = null;
      _phoneResults = [];
    });
    try {
      final list = await ref.read(staffRepositoryProvider).getCustomerByPhone(e164);
      if (!mounted) return;
      setState(() {
        _phoneResults = list;
        if (list.isEmpty) {
          _phoneErr = l10n.staffNoCustomerForPhone;
        }
      });
      if (list.length == 1) {
        staffSuccessSound();
        staffHaptic();
        ref.read(staffCustomerProvider.notifier).select(list.single);
        if (!mounted) return;
        context.go('/staff/customer-card');
      }
    } catch (e) {
      if (mounted) setState(() => _phoneErr = '$e');
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pending = ref.watch(offlinePendingCountProvider);
    final storeAsync = ref.watch(_staffStoreViewProvider);

    final roleLabel = storeAsync.asData?.value.role == 'owner'
        ? l10n.roleOwnerLabel
        : (storeAsync.asData?.value.role == 'manager'
            ? l10n.roleManager
            : l10n.roleStaffMember);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(
          backgroundColor: _kPageBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: storeAsync.when(
            loading: () => const Text('...'),
            error: (_, __) => const Text('المتجر'),
            data: (s) {
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (s.logoUrl == null || s.logoUrl!.isEmpty)
                        ? Center(
                            child: Text(
                              _initials(s.storeName),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Color(0xFF111827),
                              ),
                            ),
                          )
                        : Image.network(
                            s.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                _initials(s.storeName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _kPointBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_sync_outlined,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$pending',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: _kPointBlue),
              tooltip: l10n.logout,
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 20),
          children: [
            _CameraCard(
              cam: _cam,
              scanMsg: _scanMsg,
              onDetect: (v) => unawaited(_onQr(v)),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '──── أو ────',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'رقم الجوال',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            '🇸🇦  +966',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            textDirection: TextDirection.ltr,
                            keyboardType: TextInputType.phone,
                            maxLength: 9,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '5XXXXXXXX',
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _kPointBlue, width: 1.8),
                              ),
                            ),
                            onSubmitted: (_) => _searchByPhone(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _phoneBusy ? null : _searchByPhone,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kPointBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _phoneBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('بحث', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_phoneErr != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _phoneErr!,
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right,
                    ),
                  ],
                  if (_phoneResults.length > 1) ...[
                    const SizedBox(height: 14),
                    Text(
                      l10n.staffPickCustomer,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _phoneResults.map((c) {
                        return ActionChip(
                          label: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            staffSuccessSound();
                            ref.read(staffCustomerProvider.notifier).select(c);
                            context.go('/staff/customer-card');
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.cam,
    required this.onDetect,
    required this.scanMsg,
  });

  final MobileScannerController cam;
  final void Function(String raw) onDetect;
  final String? scanMsg;

  static Rect _frameRect(Size size) {
    const dim = 200.0;
    final left = (size.width - dim) / 2;
    final top = (size.height - dim) / 2;
    return Rect.fromLTWH(left, top, dim, dim);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: cam,
            onDetect: (capture) {
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.isNotEmpty) {
                  onDetect(v);
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
                  painter: _CornerOnlyPainter(frame: _frameRect(Size(c.maxWidth, c.maxHeight))),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Text(
              l10n.staffScanCustomerQr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ),
          if (scanMsg != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Material(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(
                      scanMsg!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (disableAnim)
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _CornerOnlyPainter extends CustomPainter {
  _CornerOnlyPainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 28.0;

    // Top-left
    canvas.drawLine(Offset(frame.left, frame.top), Offset(frame.left + corner, frame.top), paint);
    canvas.drawLine(Offset(frame.left, frame.top), Offset(frame.left, frame.top + corner), paint);
    // Top-right
    canvas.drawLine(Offset(frame.right, frame.top), Offset(frame.right - corner, frame.top), paint);
    canvas.drawLine(Offset(frame.right, frame.top), Offset(frame.right, frame.top + corner), paint);
    // Bottom-left
    canvas.drawLine(Offset(frame.left, frame.bottom), Offset(frame.left + corner, frame.bottom), paint);
    canvas.drawLine(Offset(frame.left, frame.bottom), Offset(frame.left, frame.bottom - corner), paint);
    // Bottom-right
    canvas.drawLine(Offset(frame.right, frame.bottom), Offset(frame.right - corner, frame.bottom), paint);
    canvas.drawLine(Offset(frame.right, frame.bottom), Offset(frame.right, frame.bottom - corner), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerOnlyPainter oldDelegate) => oldDelegate.frame != frame;
}
