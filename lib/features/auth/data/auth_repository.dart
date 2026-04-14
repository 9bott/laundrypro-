import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/supabase_constants.dart';

enum AppRole { customer, staff }

/// Whether to use Supabase-native phone OTP instead of Firebase phone auth.
/// Firebase verifyPhoneNumber crashes on iOS 18 due to a reCAPTCHA keyWindow
/// nil force-unwrap, so we bypass it entirely on Apple platforms.
bool get _useSupabaseOtp => !kIsWeb && Platform.isIOS;

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  String? _verificationId;

  factory AuthRepository.fromEnv() =>
      AuthRepository(SupabaseService.client);

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  Future<void> signInWithPhoneOtp(String e164Phone) async {
    debugPrint('[AUTH] signInWithPhoneOtp called: $e164Phone (supabaseOtp=$_useSupabaseOtp)');

    if (_useSupabaseOtp) {
      try {
        await _client.auth.signInWithOtp(phone: e164Phone);
        debugPrint('[AUTH] Supabase OTP sent to $e164Phone');
      } catch (e) {
        debugPrint('[AUTH] Supabase OTP failed: $e — ensure Phone provider is enabled in Supabase Dashboard');
        rethrow;
      }
      return;
    }

    try {
      _verificationId = null;
      final completer = Completer<void>();

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164Phone,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await Future.microtask(() async {
            try {
              await FirebaseAuth.instance.signInWithCredential(credential);
              final vid = credential.verificationId;
              if (vid != null && vid.isNotEmpty) {
                _verificationId = vid;
              }
            } catch (e) {
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
              return;
            }
            if (!completer.isCompleted) completer.complete();
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          Future.microtask(() {
            if (!completer.isCompleted) completer.completeError(e);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          Future.microtask(() {
            _verificationId = verificationId;
            if (!completer.isCompleted) completer.complete();
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          Future.microtask(() {
            _verificationId = verificationId;
            if (!completer.isCompleted) completer.complete();
          });
        },
      );

      return completer.future;
    } catch (e, stack) {
      debugPrint('[AUTH] signInWithPhoneOtp FAILED: $e');
      rethrow;
    }
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    if (!Env.hasSupabase) {
      throw const AuthException(
        'Supabase not configured. Run the app with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    if (_useSupabaseOtp) {
      return _verifyViaSupabase(phone: phone, token: token);
    }

    return _verifyViaFirebase(phone: phone, token: token);
  }

  /// iOS path: verify OTP directly through Supabase (no Firebase involved).
  Future<AuthResponse> _verifyViaSupabase({
    required String phone,
    required String token,
  }) async {
    debugPrint('[AUTH] verifyViaSupabase phone=$phone');
    return _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Android path: verify OTP through Firebase, exchange ID token for Supabase session.
  Future<AuthResponse> _verifyViaFirebase({
    required String phone,
    required String token,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    late final String idToken;

    if (firebaseUser != null) {
      final fbPhone = firebaseUser.phoneNumber;
      if (fbPhone != null && _normalizeE164(fbPhone) != _normalizeE164(phone)) {
        await FirebaseAuth.instance.signOut();
        throw const AuthException('Phone number mismatch');
      }
      final t = await firebaseUser.getIdToken();
      if (t == null || t.isEmpty) {
        throw const AuthException('Failed to read Firebase ID token');
      }
      idToken = t;
    } else {
      final vid = _verificationId;
      if (vid == null || vid.isEmpty) {
        throw const AuthException(
          'Verification session expired. Request a new code.',
        );
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: token,
      );
      final firebaseResult =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final t = await firebaseResult.user?.getIdToken();
      if (t == null || t.isEmpty) {
        throw const AuthException('Firebase sign-in failed');
      }
      idToken = t;
    }

    try {
      final response = await _client.functions.invoke(
        'firebase-auth',
        body: {'idToken': idToken, 'phone': phone},
      );

      final data = response.data;
      if (data is! Map) {
        throw const AuthException('Invalid exchange response');
      }
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const AuthException('Missing refresh_token from server');
      }
      return _client.auth.setSession(refreshToken);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['message'] is String) {
        throw AuthException(details['message'] as String);
      }
      throw AuthException('Exchange failed (${e.status})');
    }
  }

  String _normalizeE164(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return value.trim();
    return '+$digits';
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLoginModePrefKey);
    // Do not prefs.clear(): it wipes Supabase's persisted session key, locale,
    // remember_me, etc. Supabase auth.signOut removes the auth token via listener.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _verificationId = null;
    await _client.auth.signOut();
  }

  /// Resolves role: أي مستخدم نشط في جدول الموظفين = موظف (بما فيه المالك/المدير).
  Future<AppRole> resolveRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return AppRole.customer;

    final staff = await _client
        .from(kTableStaff)
        .select(kStaffRole)
        .eq(kStaffAuthUserId, user.id)
        .eq(kStaffIsActive, true)
        .maybeSingle();

    if (staff == null) return AppRole.customer;
    return AppRole.staff;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository.fromEnv();
});
