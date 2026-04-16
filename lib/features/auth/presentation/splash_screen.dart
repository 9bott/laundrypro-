import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/router/auth_route_resolution.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/biometric_service.dart';
import '../data/auth_repository.dart';

/// Same key pattern as [SharedPreferencesLocalStorage] in supabase_flutter.
String _supabaseAuthPersistKey(String supabaseUrl) {
  final host = Uri.parse(supabaseUrl.trim()).host;
  final ref = host.split('.').first;
  return 'sb-$ref-auth-token';
}

void _splashLog(String message) {
  if (kDebugMode) debugPrint('[Splash] $message');
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _error;
  late DateTime _splashShownAt;

  static const _minSplashVisible = Duration(milliseconds: 850);

  @override
  void initState() {
    super.initState();
    _splashShownAt = DateTime.now();
    _boot();
  }

  Future<void> _ensureMinSplashVisible() async {
    final elapsed = DateTime.now().difference(_splashShownAt);
    if (elapsed < _minSplashVisible) {
      await Future<void>.delayed(_minSplashVisible - elapsed);
    }
  }

  Future<void> _navigate(String location) async {
    await _ensureMinSplashVisible();
    if (!mounted) return;
    context.go(location);
  }

  Future<void> _boot() async {
    if (!Env.hasSupabase) {
      setState(() {
        _error = 'أضف SUPABASE_URL و SUPABASE_ANON_KEY عند التشغيل (dart-define).';
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(kRememberMePrefKey) ?? true;
      final loginModeRaw = prefs.getString(kLoginModePrefKey);
      final persistKey = _supabaseAuthPersistKey(Env.supabaseUrl);
      final persistedSessionStr = prefs.getString(persistKey);

      _splashLog('boot start');
      _splashLog(
        'remember_me=$rememberMe (pref raw: ${prefs.get(kRememberMePrefKey)})',
      );
      _splashLog(
        'kLoginModePrefKey="$loginModeRaw" (expected staff|customer)',
      );
      _splashLog(
        'persisted Supabase session: key="$persistKey" '
        'present=${persistedSessionStr != null} '
        'len=${persistedSessionStr?.length ?? 0}',
      );

      if (!rememberMe) {
        _splashLog('DECISION: sign out + /auth/phone (remember_me false)');
        await ref.read(authRepositoryProvider).signOut();
        if (!mounted) return;
        await _navigate('/auth/phone');
        return;
      }

      var session = Supabase.instance.client.auth.currentSession;
      _splashLog(
        'currentSession after init: '
        '${session == null ? "null" : "userId=${session.user.id} isExpired=${session.isExpired}"}',
      );

      // If memory is empty but disk has JSON, recover (handles failed setInitialSession / races).
      if (session == null &&
          persistedSessionStr != null &&
          persistedSessionStr.isNotEmpty) {
        _splashLog('attempting recoverSession from SharedPreferences…');
        try {
          await Supabase.instance.client.auth
              .recoverSession(persistedSessionStr);
          session = Supabase.instance.client.auth.currentSession;
          _splashLog(
            'recoverSession done: '
            '${session == null ? "still null" : "userId=${session.user.id} isExpired=${session.isExpired}"}',
          );
        } catch (e, st) {
          _splashLog('recoverSession FAILED: $e');
          if (kDebugMode) {
            debugPrintStack(stackTrace: st, label: '[Splash]');
          }
        }
      }

      // Try refresh if JWT is past margin (cold start before auto-refresh runs).
      if (session != null && session.isExpired) {
        _splashLog('session expired → refreshSession()…');
        try {
          await Supabase.instance.client.auth.refreshSession();
          session = Supabase.instance.client.auth.currentSession;
          _splashLog(
            'after refresh: '
            '${session == null ? "null" : "userId=${session.user.id} isExpired=${session.isExpired}"}',
          );
        } catch (e) {
          _splashLog('refreshSession FAILED: $e');
        }
      }

      // No valid session → login (clear saved role)
      if (session == null || session.isExpired) {
        _splashLog(
          'DECISION: no valid session → signOut + /auth/phone '
          '(sessionNull=${session == null} isExpired=${session?.isExpired})',
        );
        await prefs.remove(kLoginModePrefKey);
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        await _navigate('/auth/phone');
        return;
      }

      // Session valid → must have a saved login mode (set at phone screen before OTP)
      final loginMode = prefs.getString(kLoginModePrefKey);
      _splashLog('loginMode for routing="$loginMode"');

      if (loginMode != kLoginModeStaff && loginMode != kLoginModeCustomer) {
        _splashLog(
          'DECISION: invalid/missing login_mode → signOut + /auth/phone',
        );
        await prefs.remove(kLoginModePrefKey);
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        await _navigate('/auth/phone');
        return;
      }

      // بصمة / Face ID تلقائياً عند وجود جلسة صالحة (بدون انتظار زر) — أول دخول يبقى هاتف + OTP.
      final biometricEnabled = await BiometricService.isEnabled();
      final biometricAvailable = await BiometricService.isAvailable();
      _splashLog(
        'biometric enabled=$biometricEnabled available=$biometricAvailable',
      );

      if (biometricEnabled && biometricAvailable) {
        final authenticated = await BiometricService.authenticate();
        _splashLog('biometric authenticate → $authenticated');
        if (!authenticated) {
          _splashLog(
            'DECISION: biometric failed/cancelled → signOut + /auth/phone',
          );
          await prefs.remove(kLoginModePrefKey);
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          await _navigate('/auth/phone');
          return;
        }
      }

      final resolved = await resolveRouteAfterOtp();
      if (resolved != null && resolved != '/auth/phone') {
        _splashLog('DECISION: resolveRouteAfterOtp → $resolved');
        if (mounted) await _navigate(resolved);
        return;
      }

      if (loginMode == kLoginModeStaff) {
        _splashLog('DECISION: route → /staff/app (login_mode=staff, fallback)');
        if (mounted) await _navigate('/staff/app');
      } else if (loginMode == kLoginModeCustomer) {
        _splashLog('DECISION: route → /customer/home (login_mode=customer, fallback)');
        if (mounted) await _navigate('/customer/home');
      }
    } catch (e, st) {
      _splashLog('boot EXCEPTION: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: st, label: '[Splash]');
      }
      setState(() => _error = '$e');
    }
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _splashShownAt = DateTime.now();
                      _boot();
                    },
                    child: Text(isAr ? AppStrings.retryAr : AppStrings.retryEn),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final logoSide = (shortest * 0.34).clamp(132.0, 188.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  const startScale = 0.82;
                  final scale = startScale + (1.0 - startScale) * t;
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: logoSide,
                    height: logoSide,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.local_laundry_service,
                        size: logoSide * 0.45,
                        color: AppColors.primary,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isAr ? AppStrings.splashLoadingAr : AppStrings.splashLoadingEn,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 148,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Color(0x33B3D7FF),
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
