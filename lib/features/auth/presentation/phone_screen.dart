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
import '../../../shared/widgets/animated_bg.dart';
import '../../../shared/widgets/app_logo_loader.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../data/auth_repository.dart';

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
    // keep only western digits
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
  bool _loading = false;
  bool _asStaff = false;
  bool _rememberMe = true;
  bool _bioEnabled = false;
  bool _bioAvailable = false;
  bool _bioBusy = false;
  /// جلسة محفوظة صالحة (بعد أول تسجيل دخول بـ OTP) — البصمة لا تُستخدم لأول مرة.
  bool _hasValidPersistedSession = false;
  String _biometricLoginAsset = AppAssets.fingerprintLoginIcon;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  bool _validNine(String d) =>
      d.length == 9 && d.startsWith('5') && RegExp(r'^[0-9]+$').hasMatch(d);

  /// Same key pattern as SharedPreferencesLocalStorage in supabase_flutter.
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
      } catch (_) {
        // If recover fails, we'll fall back to requiring OTP login.
      }
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
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(kRememberMePrefKey) ?? true;
    final bioEnabled = await BiometricService.isEnabled();
    final bioAvailable = await BiometricService.isAvailable();
    final loginMode = prefs.getString(kLoginModePrefKey);
    final session = await _ensureSupabaseSession();
    final bioIcon = await BiometricService.loginIconAssetPath();
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

      // Ensure Supabase session is present/valid before resolving role + routing.
      final session = await _ensureSupabaseSession();
      if (session == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAr
                  ? 'انتهت الجلسة. سجّل دخول مرة واحدة بالرسالة ثم جرّب البصمة.'
                  : 'Session expired. Sign in once with OTP, then use biometrics.',
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

  /// Persists [kLoginModePrefKey] from the **current** tab ([_asStaff]) immediately before OTP,
  /// so a fast tap on Sign in cannot race the async Store/Customer segment handlers.
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
        const SnackBar(content: Text('Supabase not configured')),
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
      context.push('/auth/otp', extra: phone);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_isAr ? AppStrings.errorGenericAr : AppStrings.errorGenericEn}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    return OfflineBanner(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBackground(
          extraOrbs: true,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isAr ? AppStrings.appNameAr : AppStrings.appNameEn,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAr ? AppStrings.taglineAr : AppStrings.taglineEn,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _segButton(
                                        context,
                                        label: isAr ? 'عميل' : 'Customer',
                                        selected: !_asStaff,
                                        onTap: () async {
                                          final p =
                                              await SharedPreferences.getInstance();
                                          await p.setString(
                                            kLoginModePrefKey,
                                            kLoginModeCustomer,
                                          );
                                          if (mounted) {
                                            setState(() => _asStaff = false);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _segButton(
                                        context,
                                        label: isAr ? 'متجر' : 'Store',
                                        selected: _asStaff,
                                        onTap: () async {
                                          final p =
                                              await SharedPreferences.getInstance();
                                          await p.setString(
                                            kLoginModePrefKey,
                                            kLoginModeStaff,
                                          );
                                          if (mounted) {
                                            setState(() => _asStaff = true);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isAr ? 'رقم الجوال' : 'Mobile number',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
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
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: const Text(
                                        '🇸🇦  +966',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
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
                                          hintText: isAr
                                              ? AppStrings.phoneHintAr
                                              : AppStrings.phoneHintEn,
                                          counterText: '',
                                          filled: true,
                                          fillColor: AppColors.surface,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: const BorderSide(
                                              color: AppColors.borderDark,
                                              width: 1.6,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 2.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAr ? 'مثال: 5XXXXXXXX' : 'Example: 5XXXXXXXX',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textHint,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Transform.scale(
                                          scale: 0.9,
                                          child: Checkbox(
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            value: _rememberMe,
                                            onChanged: _loading
                                                ? null
                                                : (v) => _setRememberMe(v ?? true),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            isAr ? 'تذكرني' : 'Remember me',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textSecondary,
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
                                            scale: 0.9,
                                            child: Switch(
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                              value: _bioEnabled && _rememberMe,
                                              onChanged: (!_rememberMe || _loading)
                                                  ? null
                                                  : (v) => _setBiometricEnabled(v),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isAr
                                                  ? 'الدخول عبر Face ID / البصمة'
                                                  : 'Login with Face ID / biometrics',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textSecondary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        isAr
                                            ? 'يتطلب بصمة/Face ID لفتح التطبيق عند وجود جلسة محفوظة.'
                                            : 'Requires biometrics to open the app when a session is saved.',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.textHint,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!Env.hasSupabase) ...[
                                const SizedBox(height: 10),
                                Text(
                                  isAr
                                      ? 'ملاحظة: Supabase غير مهيأ حالياً.'
                                      : 'Note: Supabase is not configured.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: (_loading || _bioBusy)
                                    ? null
                                    : _submitPhoneOtp,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: (_loading || _bioBusy)
                                    ? const AppLogoLoader(
                                        size: 28,
                                        background: Colors.transparent,
                                        showShadow: false,
                                        borderRadius: 10,
                                      )
                                    : Text(
                                        isAr ? 'تسجيل الدخول' : 'Sign in',
                                      ),
                              ),
                              if (_bioEnabled &&
                                  _bioAvailable &&
                                  _hasValidPersistedSession) ...[
                                const SizedBox(height: 18),
                                Center(
                                  child: Opacity(
                                    opacity: (_loading || _bioBusy) ? 0.45 : 1,
                                    child: Material(
                                      color: AppColors.surface,
                                      shape: CircleBorder(
                                        side: BorderSide(
                                          color: AppColors.border.withValues(
                                            alpha: 0.9,
                                          ),
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
                                                    (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.fingerprint,
                                                    size: 36,
                                                    color:
                                                        AppColors.textPrimary,
                                                  );
                                                },
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
                                  isAr
                                      ? 'لتفعيل الدخول بالبصمة: فعّل "تذكرني" ثم سجّل دخول مرة واحدة بالرسالة.'
                                      : 'To enable biometrics: turn on Remember me, then sign in once with OTP.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textHint,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isAr ? 'سيتم إرسال رمز تحقق لمرة واحدة.' : 'OTP will be sent via SMS.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _segButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryBorder : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
