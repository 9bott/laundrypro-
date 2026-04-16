import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/biometric_service.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../data/auth_repository.dart';

const Color _kPointBlue = Color(0xFF185FA5);
const Color _kPageBg = Color(0xFFF8F9FA);

class _ArabicDigitsToWesternFormatter extends TextInputFormatter {
  const _ArabicDigitsToWesternFormatter();

  static const _west = '0123456789';
  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  String _normalize(String input) {
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
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
      composing: TextRange.empty,
    );
  }
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _initLoaded = false;
  bool _loading = false;
  bool _asStaff = false;
  bool _rememberMe = true;
  bool _bioEnabled = false;
  bool _bioAvailable = false;
  bool _bioBusy = false;
  bool _hasValidPersistedSession = false;
  String _biometricLoginAsset = AppAssets.fingerprintLoginIcon;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  bool _validNine(String d) =>
      d.length == 9 && d.startsWith('5') && RegExp(r'^[0-9]+$').hasMatch(d);

  String _supabaseAuthPersistKey(String supabaseUrl) {
    final host = Uri.parse(supabaseUrl.trim()).host;
    final ref = host.split('.').first;
    return 'sb-$ref-auth-token';
  }

  Future<Session?> _ensureSupabaseSession() async {
    if (!Env.hasSupabase) return null;

    var session = Supabase.instance.client.auth.currentSession;
    if (session != null && !session.isExpired) return session;

    final prefs = await SharedPreferences.getInstance();
    final persistKey = _supabaseAuthPersistKey(Env.supabaseUrl);
    final persistedSessionStr = prefs.getString(persistKey);

    if (session == null &&
        persistedSessionStr != null &&
        persistedSessionStr.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.recoverSession(persistedSessionStr);
      } catch (_) {}
      session = Supabase.instance.client.auth.currentSession;
    }

    if (session != null && session.isExpired) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      session = Supabase.instance.client.auth.currentSession;
    }

    return (session != null && !session.isExpired) ? session : null;
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) {
      if (mounted) setState(() => _initLoaded = true);
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(kRememberMePrefKey) ?? true;
    bool bioEnabled = false;
    bool bioAvailable = false;
    String bioIcon = AppAssets.fingerprintLoginIcon;
    final loginMode = prefs.getString(kLoginModePrefKey);
    final session = await _ensureSupabaseSession();
    try {
      bioEnabled = await BiometricService.isEnabled();
      bioAvailable = await BiometricService.isAvailable();
      bioIcon = await BiometricService.loginIconAssetPath();
    } catch (e) {
      debugPrint('[PhoneScreen] biometric init error: $e');
      bioAvailable = false;
      bioEnabled = false;
    }
    if (!mounted) return;
    setState(() {
      _rememberMe = rememberMe;
      _bioAvailable = bioAvailable;
      _bioEnabled = bioEnabled && bioAvailable && rememberMe;
      _hasValidPersistedSession = session != null;
      _biometricLoginAsset = bioIcon;
      if (loginMode == kLoginModeStaff) {
        _asStaff = true;
      } else if (loginMode == kLoginModeCustomer) {
        _asStaff = false;
      }
    });
  }

  Future<void> _setRememberMe(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kRememberMePrefKey, v);
    if (!v) {
      await BiometricService.setEnabled(false);
    }
    final session = await _ensureSupabaseSession();
    if (!mounted) return;
    setState(() {
      _rememberMe = v;
      if (!v) _bioEnabled = false;
      _hasValidPersistedSession = session != null;
    });
  }

  Future<void> _setBiometricEnabled(bool v) async {
    await BiometricService.setEnabled(v);
    if (!mounted) return;
    setState(() => _bioEnabled = v);
  }

  Future<void> _loginWithBiometrics() async {
    if (_bioBusy || _loading) return;
    final auth = ref.read(authRepositoryProvider);

    setState(() => _bioBusy = true);
    try {
      final ok = await BiometricService.authenticate();
      if (!ok) return;

      final session = await _ensureSupabaseSession();
      if (session == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'انتهت الجلسة. سجّل دخول مرة واحدة بالرسالة ثم جرّب البصمة.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final role = await auth.resolveRole();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      switch (role) {
        case AppRole.staff:
          await prefs.setString(kLoginModePrefKey, kLoginModeStaff);
          if (!mounted) return;
          context.go('/staff/scanner');
          break;
        case AppRole.customer:
          await prefs.setString(kLoginModePrefKey, kLoginModeCustomer);
          if (!mounted) return;
          context.go('/customer/home');
          break;
      }
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _submitPhoneOtp() async {
    final digits = _controller.text.trim();
    if (!_validNine(digits)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAr ? AppStrings.phoneInvalidAr : AppStrings.phoneInvalidEn),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!Env.hasSupabase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف SUPABASE_URL و SUPABASE_ANON_KEY عند التشغيل.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final phone = '+966$digits';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kLoginModePrefKey,
        _asStaff ? kLoginModeStaff : kLoginModeCustomer,
      );
      await ref.read(authRepositoryProvider).signInWithPhoneOtp(phone);
      if (!mounted) return;
      context.pushReplacement('/auth/otp', extra: phone);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.errorGenericAr}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setTab(bool staff) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kLoginModePrefKey,
      staff ? kLoginModeStaff : kLoginModeCustomer,
    );
    if (mounted) setState(() => _asStaff = staff);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: OfflineBanner(
        child: Scaffold(
          backgroundColor: _kPageBg,
          body: !_initLoaded
              ? const Center(child: CircularProgressIndicator(color: _kPointBlue))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final topH = h * 0.4;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            Container(
                              height: topH,
                              width: double.infinity,
                              color: _kPointBlue,
                              child: SafeArea(
                                bottom: false,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/app_logo.png',
                                      height: 88,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'بوينت',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'نظام الولاء الذكي',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: topH - 28,
                          bottom: 0,
                          child: Material(
                            color: Colors.white,
                            elevation: 12,
                            shadowColor: Colors.black26,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      40,
                                      16,
                                      16,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 220),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: Column(
                                        key: ValueKey(_asStaff),
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildTabSwitcher(),
                                          const SizedBox(height: 24),
                                          const Text(
                                            'رقم الجوال',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF444444),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: const Color(0xFFE2E4E8),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    '🇸🇦  +966',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _controller,
                                                    textDirection: TextDirection.ltr,
                                                    keyboardType: TextInputType.phone,
                                                    maxLength: 9,
                                                    textAlign: TextAlign.left,
                                                    inputFormatters: const [
                                                      _ArabicDigitsToWesternFormatter(),
                                                    ],
                                                    decoration: InputDecoration(
                                                      hintText: '5XXXXXXXX',
                                                      counterText: '',
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 16,
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                        borderSide: const BorderSide(
                                                          color: Color(0xFFE2E4E8),
                                                        ),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                        borderSide: const BorderSide(
                                                          color: _kPointBlue,
                                                          width: 1.8,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'مثال: 5XXXXXXXX',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          _buildRememberBiometricBlock(),
                                          if (!Env.hasSupabase) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              'ملاحظة: Supabase غير مهيأ حالياً.',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 22),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 54,
                                            child: FilledButton(
                                              onPressed: (!_initLoaded ||
                                                      _loading ||
                                                      _bioBusy)
                                                  ? null
                                                  : _submitPhoneOtp,
                                              style: FilledButton.styleFrom(
                                                backgroundColor: _kPointBlue,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    _kPointBlue.withValues(alpha: 0.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: (_loading || _bioBusy)
                                                  ? const SizedBox(
                                                      width: 26,
                                                      height: 26,
                                                      child: AppLogoLoader(
                                                        size: 26,
                                                        background: Colors.transparent,
                                                        showShadow: false,
                                                        borderRadius: 8,
                                                      ),
                                                    )
                                                  : const Text(
                                                      'تسجيل الدخول',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (_asStaff) ...[
                                            const SizedBox(height: 12),
                                            TextButton(
                                              onPressed: _loading || _bioBusy
                                                  ? null
                                                  : _submitPhoneOtp,
                                              child: const Text(
                                                'أنشئ متجرك',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: _kPointBlue,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (_bioEnabled &&
                                              _bioAvailable &&
                                              _hasValidPersistedSession) ...[
                                            const SizedBox(height: 18),
                                            Center(
                                              child: Opacity(
                                                opacity: (_loading || _bioBusy) ? 0.45 : 1,
                                                child: Material(
                                                  color: Colors.white,
                                                  shape: CircleBorder(
                                                    side: BorderSide(
                                                      color: Colors.grey.shade300,
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: InkWell(
                                                    onTap: (_loading || _bioBusy)
                                                        ? null
                                                        : _loginWithBiometrics,
                                                    customBorder: const CircleBorder(),
                                                    child: SizedBox(
                                                      width: 70,
                                                      height: 70,
                                                      child: Center(
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(14),
                                                          child: Image.asset(
                                                            _biometricLoginAsset,
                                                            fit: BoxFit.contain,
                                                            errorBuilder:
                                                                (_, __, ___) =>
                                                                    const Icon(
                                                              Icons.fingerprint,
                                                              size: 36,
                                                              color: _kPointBlue,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (_bioAvailable &&
                                              (!_hasValidPersistedSession ||
                                                  !_bioEnabled ||
                                                  !_rememberMe)) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              'لتفعيل الدخول بالبصمة: فعّل «تذكرني» ثم سجّل دخول مرة واحدة بالرسالة.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                height: 1.35,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    12 + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  child: Text(
                                    'سيتم إرسال رمز تحقق عبر SMS',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: !_asStaff ? _kPointBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _loading ? null : () => _setTab(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'عميل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: !_asStaff ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: _asStaff ? _kPointBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _loading ? null : () => _setTab(true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'متجر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _asStaff ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberBiometricBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Transform.scale(
                scale: 0.92,
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: _rememberMe,
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return _kPointBlue;
                    }
                    return null;
                  }),
                  onChanged: _loading ? null : (v) => _setRememberMe(v ?? true),
                ),
              ),
              const Expanded(
                child: Text(
                  'تذكرني',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),
          if (_bioAvailable) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Transform.scale(
                  scale: 0.92,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: _bioEnabled && _rememberMe,
                  activeTrackColor: _kPointBlue.withValues(alpha: 0.45),
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? _kPointBlue
                        : Colors.grey,
                  ),
                  onChanged: (!_rememberMe || _loading)
                      ? null
                      : (v) => _setBiometricEnabled(v),
                ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppAssets.faceIdLoginIcon,
                          height: 22,
                          width: 22,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.face_rounded,
                            size: 22,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset(
                          AppAssets.fingerprintLoginIcon,
                          height: 22,
                          width: 22,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.fingerprint,
                            size: 22,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'يتطلب بصمة أو Face ID عند وجود جلسة محفوظة.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
