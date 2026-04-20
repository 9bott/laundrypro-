import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../constants/supabase_constants.dart';
import '../router/app_router.dart';

/// FCM + local notification hooks.
/// TODO: Add `FirebaseOptions` from `google-services.json` / `GoogleService-Info.plist`
/// via `flutterfire configure` — without it, Firebase may fail on real devices.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[Firebase] skipped: $e');
  }
}

abstract final class NotificationService {
  static bool _didInit = false;
  static String? _lastSyncedToken;

  static Future<void> initialize() async {
    if (_didInit) return;
    _didInit = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('[Firebase] skipped: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Foreground: show an in-app banner (SnackBar) to avoid silent delivery.
      FirebaseMessaging.onMessage.listen((msg) {
        _showForegroundBanner(msg);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        _handlePayload(msg.data);
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePayload(initial.data);
        });
      }

      // Token sync: on launch, on token refresh, and on Supabase auth changes.
      await _syncFcmTokenForCurrentUser();
      FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
        await _syncFcmTokenForCurrentUser(force: true);
      });
      Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
        // On sign-in / sign-out, attempt a resync (no-op if missing user/token).
        await _syncFcmTokenForCurrentUser(force: true);
      });
    } catch (e) {
      debugPrint('[Firebase] skipped: $e');
    }
  }

  /// Backwards compatible helper: if you already know the customer id, persist
  /// the token after login. Writes both legacy `device_token` and new `fcm_token`.
  static Future<void> syncCustomerDeviceToken(String? customerId) async {
    if (customerId == null) return;
    if (Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supabase.instance.client.from(kTableCustomers).update({
        kCustomersDeviceToken: token,
        kCustomersFcmToken: token,
      }).eq(kCustomersId, customerId);
      _lastSyncedToken = token;
    } catch (e) {
      debugPrint('[fcm_token] $e');
    }
  }

  static Future<void> _syncFcmTokenForCurrentUser({bool force = false}) async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      if (!force && _lastSyncedToken == token) return;

      final prefs = await SharedPreferences.getInstance();
      final loginMode = prefs.getString(kLoginModePrefKey);

      if (loginMode == kLoginModeStaff) {
        await Supabase.instance.client.from(kTableStaff).update({
          kStaffFcmToken: token,
        }).eq(kStaffAuthUserId, user.id);
      } else {
        // Default to customer (covers owner/customer without pref).
        await Supabase.instance.client.from(kTableCustomers).update({
          kCustomersDeviceToken: token, // legacy fallback
          kCustomersFcmToken: token,
        }).eq(kCustomersAuthUserId, user.id);
      }

      _lastSyncedToken = token;
    } catch (e) {
      debugPrint('[fcm_token] $e');
    }
  }

  static void _showForegroundBanner(RemoteMessage msg) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    // Prefer notification title/body, fall back to known payload types.
    final title = msg.notification?.title ?? 'Point';
    final body = msg.notification?.body ??
        (msg.data['body'] as String?) ??
        (msg.data['type'] != null ? 'لديك إشعار جديد' : 'Notification');

    try {
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: (Localizations.localeOf(ctx).languageCode == 'ar')
                ? 'فتح'
                : 'Open',
            onPressed: () => _handlePayload(msg.data),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[fcm_foreground] $e');
    }
  }

  static void _handlePayload(Map<String, dynamic> data) {
    final route = data['route'] as String? ?? _routeForType(data);
    final ctx = rootNavigatorKey.currentContext;
    if (route == null || ctx == null) return;
    try {
      GoRouter.of(ctx).go(route);
    } catch (e) {
      debugPrint('[fcm_nav] $e');
    }
  }

  static String? _routeForType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return null;
    // Keep it simple: route to customer wallet for balance-impacting events.
    switch (type) {
      case 'purchase':
      case 'redeem':
      case 'subscription':
      case 'welcome':
        return '/customer/wallet';
      case 'fraud':
        return '/owner/fraud';
      default:
        return null;
    }
  }
}
