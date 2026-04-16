import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../customer/presentation/providers/customer_providers.dart';
import '../../staff/data/staff_repository.dart';
import '../../staff/presentation/providers/staff_providers.dart';

/// Normalizes Arabic/Persian digits and keeps at most [kPhoneOtpCodeLength] digits.
class _OtpCodeFormatter extends TextInputFormatter {
  const _OtpCodeFormatter();

  static const _west = '0123456789';
  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  static String _normalize(String input) {
    var out = input;
    for (var i = 0; i < _west.length; i++) {
      out = out.replaceAll(_arabicIndic[i], _west[i]);
      out = out.replaceAll(_persian[i], _west[i]);
    }
    return out;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = _normalize(newValue.text);
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > kPhoneOtpCodeLength
        ? digits.substring(0, kPhoneOtpCodeLength)
        : digits;
    if (limited == newValue.text) return newValue;
    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
      composing: TextRange.empty,
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();
  late AnimationController _shake;

  int _resendSeconds = 0;
  Timer? _resendTimer;
  bool _busy = false;
  String? _error;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  Future<bool> _isNameTaken(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final result = await Supabase.instance.client
        .from(kTableCustomers)
        .select('id')
        .ilike(kCustomersName, trimmed)
        .limit(1);
    return (result as List).isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _otpController.addListener(_onOtpChanged);
    _startResend();
    WidgetsBinding.instance.addPostFrameCallback((_) => _otpFocus.requestFocus());
  }

  void _onOtpChanged() {
    if (!mounted) return;
    // Avoid setState here — digits rebuild via AnimatedBuilder (less jank with keyboard).
    if (_otpController.text.length == kPhoneOtpCodeLength && !_busy) {
      _verify();
    }
  }

  /// Deletes one digit before the caret (or selection). Keeps caret in the
  /// previous "box" so backspace / hold-delete feels continuous.
  void _deleteOtpBackward() {
    final t = _otpController.text;
    if (t.isEmpty) return;
    final sel = _otpController.selection;
    if (!sel.isValid) {
      _otpController.value = TextEditingValue(
        text: t.substring(0, t.length - 1),
        selection: TextSelection.collapsed(offset: t.length - 1),
        composing: TextRange.empty,
      );
      _otpFocus.requestFocus();
      return;
    }
    if (sel.start != sel.end) {
      final nt = t.replaceRange(sel.start, sel.end, '');
      final off = sel.start.clamp(0, nt.length);
      _otpController.value = TextEditingValue(
        text: nt,
        selection: TextSelection.collapsed(offset: off),
        composing: TextRange.empty,
      );
      _otpFocus.requestFocus();
      return;
    }
    final off = sel.start;
    if (off <= 0) return;
    final nt = t.replaceRange(off - 1, off, '');
    _otpController.value = TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(offset: off - 1),
      composing: TextRange.empty,
    );
    _otpFocus.requestFocus();
  }

  bool get _needsOtpDeleteButton {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  TextInputType get _otpKeyboardType {
    // iOS: TextInputType.number → UIKeyboardTypeNumberPad → NO delete key.
    // Phone / decimal pad include delete; formatter keeps digits only.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return TextInputType.phone;
    }
    return TextInputType.number;
  }

  void _startResend() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    _resendTimer?.cancel();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = _otpController.text;
    if (token.length != kPhoneOtpCodeLength) return;

    if (!Env.hasSupabase) {
      _failVerify(
        message: _isAr
            ? 'Supabase غير مهيأ. شغّل التطبيق مع SUPABASE_URL و SUPABASE_ANON_KEY.'
            : 'Supabase is not configured. Run with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).verifyPhoneOtp(
            phone: widget.phone,
            token: token,
          );

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('no_user');

      await _routeAfterOtpSuccess(user);
    } catch (e) {
      _failVerify(message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _failVerify({String? message}) {
    SharedPreferences.getInstance().then((p) => p.remove(kLoginModePrefKey));
    _shake.forward(from: 0);
    _otpController.clear();
    setState(() => _error = message ?? (_isAr ? AppStrings.errorGenericAr : AppStrings.errorGenericEn));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  /// After successful OTP: staff-first or customer-first based on [kLoginModePrefKey], then registration.
  Future<void> _routeAfterOtpSuccess(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(kLoginModePrefKey) ?? kLoginModeCustomer;
    final staffFirst = mode == kLoginModeStaff;

    final staffRepo = ref.read(staffRepositoryProvider);
    final custRepo = ref.read(customerRepositoryProvider);

    Future<void> navigateStaff(StaffMember? member) async {
      await prefs.setString(kLoginModePrefKey, kLoginModeStaff);
      ref.invalidate(staffMemberProvider);
      if (!mounted) return;
      final path = staffShellScannerPath(member);
      context.go(path);
    }

    Future<void> navigateCustomer(String customerId) async {
      await prefs.setString(kLoginModePrefKey, kLoginModeCustomer);
      await custRepo.updateCustomer(customerId, {kCustomersAuthUserId: user.id});
      ref.invalidate(currentCustomerIdProvider);
      if (!mounted) return;
      context.go('/customer/home');
    }

    if (staffFirst) {
      final staff = await staffRepo.getStaffForCurrentUser();
      if (staff != null) {
        await navigateStaff(staff);
        return;
      }
      // Store tab: never fall back to the customer app just because a customer row exists.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAr
                ? 'هذا الرقم غير مضاف كموظف في المتجر. تواصل مع المشرف أو استخدم تبويب «عميل».'
                : 'This number is not registered as store staff. Contact your branch admin, or use the Customer tab.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      await ref.read(authRepositoryProvider).signOut();
      final prefsAfter = await SharedPreferences.getInstance();
      await prefsAfter.setString(kLoginModePrefKey, kLoginModeStaff);
      if (!mounted) return;
      context.go('/auth/phone');
      return;
    } else {
      final existing = await custRepo.getCustomerIdByPhone(widget.phone);
      if (existing != null) {
        await navigateCustomer(existing);
        return;
      }
      final staff = await staffRepo.getStaffForCurrentUser();
      if (staff != null) {
        await navigateStaff(staff);
        return;
      }
    }

    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        final ctl = TextEditingController();
        String? nameError;
        var checking = false;
        return Directionality(
          textDirection: _isAr ? TextDirection.rtl : TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  _isAr ? AppStrings.registerNameTitleAr : AppStrings.registerNameTitleEn,
                ),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: ctl,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        enableSuggestions: true,
                        autocorrect: false,
                        onChanged: (_) => setState(() => nameError = null),
                        decoration: InputDecoration(
                          hintText: _isAr
                              ? AppStrings.registerNameHintAr
                              : AppStrings.registerNameHintEn,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال الاسم';
                          }
                          return null;
                        },
                      ),
                      if (nameError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            nameError!,
                            style: GoogleFonts.cairo(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: checking ? null : () => Navigator.pop(ctx),
                    child: Text(_isAr ? AppStrings.cancelAr : AppStrings.cancelEn),
                  ),
                  FilledButton(
                    onPressed: checking
                        ? null
                        : () async {
                            if (formKey.currentState?.validate() != true) return;
                            setState(() {
                              checking = true;
                              nameError = null;
                            });
                            try {
                              final taken = await _isNameTaken(ctl.text);
                              if (taken) {
                                setState(() {
                                  nameError = 'هذا الاسم مستخدم، اختر اسماً مختلفاً';
                                  checking = false;
                                });
                                return;
                              }
                              if (context.mounted) {
                                Navigator.pop(ctx, ctl.text.trim());
                              }
                            } catch (_) {
                              setState(() {
                                nameError = 'تعذر التحقق من الاسم، حاول مرة أخرى';
                                checking = false;
                              });
                            }
                          },
                    child: checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isAr ? AppStrings.saveAr : AppStrings.saveEn),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (name == null || name.isEmpty) {
      _failVerify();
      return;
    }

    try {
      await Supabase.instance.client.from(kTableCustomers).insert({
        kCustomersPhone: widget.phone,
        kCustomersName: name,
        kCustomersAuthUserId: user.id,
        kCustomersPreferredLanguage: _isAr ? 'ar' : 'en',
      });
    } on PostgrestException catch (pe) {
      if (pe.code == '23505') {
        final id = await custRepo.getCustomerIdByPhone(widget.phone);
        if (id != null) {
          await custRepo.updateCustomer(id, {kCustomersAuthUserId: user.id});
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    // Welcome bonus (best-effort): proceed regardless of success/failure.
    try {
      await SupabaseService.client.functions.invoke(
        'add-welcome-bonus',
        method: HttpMethod.post,
      );
    } catch (_) {}

    ref.invalidate(currentCustomerIdProvider);
    await prefs.setString(kLoginModePrefKey, kLoginModeCustomer);
    if (!mounted) return;
    context.go('/customer/home');
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    try {
      await ref.read(authRepositoryProvider).signInWithPhoneOtp(widget.phone);
      _startResend();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    final ph = widget.phone;
    final masked = ph.length > 6
        ? '${ph.substring(0, ph.length - 4)}••••'
        : ph;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return OfflineBanner(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // iOS: resizing body on each key causes the OTP row + keyboard to jump; keyboard overlays instead.
        resizeToAvoidBottomInset: false,
        body: AnimatedBackground(
          extraOrbs: true,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeader(
                  title: isAr ? AppStrings.otpTitleAr : AppStrings.otpTitleEn,
                  subtitle: '${isAr ? AppStrings.otpSentAr : AppStrings.otpSentEn}\n$masked',
                  trailing: IconButton(
                    onPressed: () => context.go('/auth/phone'),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomInset),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) {
                          final o = 8 * (1 - (_shake.value - 0.5).abs() * 2);
                          return Transform.translate(
                            offset: Offset(_shake.value < 0.5 ? -o : o, 0),
                            child: child,
                          );
                        },
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: AnimatedBuilder(
                            animation: Listenable.merge(
                                [_otpController, _otpFocus]),
                            builder: (context, _) {
                              final value = _otpController.value;
                              return RepaintBoundary(
                                child: SizedBox(
                                  height: 52,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            splashColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            inputDecorationTheme:
                                                const InputDecorationTheme(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder:
                                                  InputBorder.none,
                                            ),
                                          ),
                                          child: TextField(
                                            controller: _otpController,
                                            focusNode: _otpFocus,
                                            keyboardType: _otpKeyboardType,
                                            keyboardAppearance:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Brightness.dark
                                                    : Brightness.light,
                                            maxLength: kPhoneOtpCodeLength,
                                            textAlign: TextAlign.center,
                                            showCursor: false,
                                            scrollPadding: EdgeInsets.zero,
                                            enableInteractiveSelection: false,
                                            autocorrect: false,
                                            enableSuggestions: false,
                                            smartQuotesType:
                                                SmartQuotesType.disabled,
                                            smartDashesType:
                                                SmartDashesType.disabled,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: defaultTargetPlatform ==
                                                      TargetPlatform.iOS
                                                  ? const Color(0x01FFFFFF)
                                                  : Colors.transparent,
                                              height: 1.1,
                                            ),
                                            cursorColor: Colors.transparent,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder:
                                                  InputBorder.none,
                                              filled: true,
                                              fillColor: Color(0x00000000),
                                              counterText: '',
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            inputFormatters: const [
                                              _OtpCodeFormatter(),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: List.generate(
                                            kPhoneOtpCodeLength, (i) {
                                          final text = value.text;
                                          final ch = i < text.length
                                              ? text[i]
                                              : '';
                                          final focused = _otpFocus.hasFocus;
                                          final lastIdx =
                                              kPhoneOtpCodeLength - 1;
                                          final active = focused &&
                                              (i == text.length ||
                                                  (i == lastIdx &&
                                                      text.length ==
                                                          kPhoneOtpCodeLength));
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              _otpFocus.requestFocus();
                                              final len = text.length;
                                              final off =
                                                  i > len ? len : i;
                                              _otpController.selection =
                                                  TextSelection.collapsed(
                                                      offset: off);
                                            },
                                            child: Container(
                                              width: 46,
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: active
                                                      ? AppColors.primary
                                                      : AppColors
                                                          .primaryBorder,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Text(
                                                ch,
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (_needsOtpDeleteButton) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _deleteOtpBackward,
                            icon: Icon(
                              Icons.backspace_outlined,
                              size: 18,
                              color: AppColors.primary.withValues(
                                alpha: _busy ? 0.4 : 1,
                              ),
                            ),
                            label: Text(
                              isAr ? 'حذف' : 'Delete',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary.withValues(
                                  alpha: _busy ? 0.4 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      const SizedBox(height: 18),
                      if (_resendSeconds > 0)
                        Text(
                          '${isAr ? AppStrings.resendInAr : AppStrings.resendInEn} $_resendSeconds',
                          textAlign: TextAlign.center,
                        )
                      else
                        TextButton(
                          onPressed: _resend,
                          child: Text(
                            isAr ? AppStrings.resendAr : AppStrings.resendEn,
                          ),
                        ),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
