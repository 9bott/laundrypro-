import 'package:flutter/foundation.dart';
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

    // Firebase FCM token (still needed for server-side sending and iOS/APNs mapping).
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] token: $fcmToken');
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
      debugPrint('[FCM] login_mode=$loginMode user_id=${user.id}');

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
