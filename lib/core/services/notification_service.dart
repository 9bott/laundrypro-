import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../constants/supabase_constants.dart';

abstract final class NotificationService {
  static bool _didInit = false;

  static Future<void> initialize() async {
    if (_didInit) return;
    _didInit = true;
    if (kIsWeb) return;

    // On iOS, wait for the production APNs device token before requesting an
    // FCM token, and do a one-time forced token refresh to flush any stale
    // sandbox-environment FCM tokens that were cached from prior dev builds.
    // Without these steps, getToken() may reuse a cached sandbox APNs token
    // causing BadEnvironmentKeyInToken (APNs 403) on App Store / TestFlight.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _ensureApnsToken();
      await _forceTokenRefreshOnce();
    }

    // Firebase FCM token (still needed for server-side sending and iOS/APNs mapping).
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] token: ${fcmToken?.substring(0, 8)}…');
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _saveFcmTokenToSupabase(fcmToken);
      }
    } catch (e) {
      debugPrint('[FCM] getToken failed: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      await _saveFcmTokenToSupabase(token);
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((_) async {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          await _saveFcmTokenToSupabase(token);
        }
      } catch (_) {}
    });

    debugPrint('[FCM] Initialized');
  }

  /// Deletes the cached FCM token once per install to force a fresh
  /// registration against the production APNs gateway. Uses a SharedPreferences
  /// flag so the deletion only runs on the first launch after this fix ships.
  static Future<void> _forceTokenRefreshOnce() async {
    const _kResetDoneKey = 'fcm_prod_reset_v1';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kResetDoneKey) == true) return;
      debugPrint('[FCM] one-time token reset for production APNs…');
      await FirebaseMessaging.instance.deleteToken();
      await prefs.setBool(_kResetDoneKey, true);
      debugPrint('[FCM] token reset done');
    } catch (e) {
      debugPrint('[FCM] token reset failed (non-fatal): $e');
    }
  }

  /// Waits up to 10 seconds for the APNs device token to become available.
  /// Required on iOS when FirebaseAppDelegateProxyEnabled=false because
  /// didRegisterForRemoteNotificationsWithDeviceToken fires asynchronously.
  static Future<void> _ensureApnsToken() async {
    const maxAttempts = 10;
    for (var i = 0; i < maxAttempts; i++) {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null) {
        debugPrint('[FCM] APNs token ready (attempt ${i + 1})');
        return;
      }
      debugPrint('[FCM] waiting for APNs token (attempt ${i + 1})…');
      await Future.delayed(const Duration(seconds: 1));
    }
    debugPrint('[FCM] APNs token not received after $maxAttempts s — proceeding anyway');
  }

  /// Backwards-compatible hook used by older call sites.
  /// With Firebase FCM, this simply triggers a token re-sync.
  static Future<void> syncCustomerDeviceToken(String? customerId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveFcmTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('[FCM] sync token failed: $e');
    }
  }

  static Future<void> _saveFcmTokenToSupabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final loginMode = prefs.getString(kLoginModePrefKey);
      debugPrint('[FCM] login_mode=$loginMode');

      if (loginMode == kLoginModeStaff) {
        await Supabase.instance.client.from(kTableStaff).update({
          'fcm_token': token,
        }).eq(kStaffAuthUserId, user.id);
      } else {
        await Supabase.instance.client.from(kTableCustomers).update({
          'fcm_token': token,
          kCustomersDeviceToken: token,
        }).eq(kCustomersAuthUserId, user.id);
      }
    } catch (e) {
      debugPrint('[FCM] save token failed: $e');
    }
  }

  // NOTE: Notification click handling is configured by the OS / deep links.
}
