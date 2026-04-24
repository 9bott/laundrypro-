import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:convert';

import '../constants/app_constants.dart';
import '../constants/supabase_constants.dart';
import '../router/app_router.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _pointChannel = AndroidNotificationChannel(
  'point_channel',
  'Point Notifications',
  importance: Importance.max,
  playSound: true,
);

bool _didInitLocalNotifications = false;

Future<void> _ensureLocalNotificationsInitialized() async {
  if (_didInitLocalNotifications) return;
  _didInitLocalNotifications = true;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const settings = InitializationSettings(android: androidInit, iOS: iosInit);

  await _flutterLocalNotifications.initialize(
    settings,
    onDidReceiveNotificationResponse: (resp) {
      final payload = resp.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        final raw = jsonDecode(payload);
        if (raw is Map<String, dynamic>) {
          NotificationService._handlePayload(raw);
        }
      } catch (_) {}
    },
  );

  final android =
      _flutterLocalNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_pointChannel);
}

/// FCM + local notification hooks.
/// TODO: Add `FirebaseOptions` from `google-services.json` / `GoogleService-Info.plist`
/// via `flutterfire configure` — without it, Firebase may fail on real devices.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[Firebase] skipped: $e');
  }

  try {
    // Avoid duplicates: if message includes a `notification` payload, Android/iOS
    // will typically display it automatically while app is background/terminated.
    // We only render a local notification for data-only pushes.
    if (message.notification != null) return;
    await _ensureLocalNotificationsInitialized();
    await NotificationService._showLocalNotification(message);
  } catch (e) {
    debugPrint('[fcm_background] $e');
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
      await _ensureLocalNotificationsInitialized();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb) {
        debugPrint('[FCM] requesting permission (platform=$defaultTargetPlatform)');
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final settings = await messaging.getNotificationSettings();
        debugPrint('[FCM] permission status: ${settings.authorizationStatus}');
      }

      // Foreground: show a real notification banner.
      FirebaseMessaging.onMessage.listen((msg) {
        _showLocalNotification(msg);
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
  /// the token after login.
  static Future<void> syncCustomerDeviceToken(String? customerId) async {
    if (customerId == null) return;
    if (Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supabase.instance.client.from(kTableCustomers).update({
        kCustomersDeviceToken: token,
        'fcm_token': token,
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
      debugPrint('[FCM] token: $token');
      if (!force && _lastSyncedToken == token) return;

      final prefs = await SharedPreferences.getInstance();
      final loginMode = prefs.getString(kLoginModePrefKey);
      debugPrint('[FCM] login_mode=$loginMode user_id=${user.id}');
      await prefs.setString('debug_fcm_token', token);

      if (loginMode == kLoginModeStaff) {
        try {
          // Clear from customers first (token may be reused on same device).
          await Supabase.instance.client.from(kTableCustomers).update({
            'fcm_token': null,
            kCustomersDeviceToken: null,
          }).or('fcm_token.eq.$token,${kCustomersDeviceToken}.eq.$token');

          // NOTE: Remote schema has `staff.fcm_token` but may not have `staff.device_token`.
          await Supabase.instance.client.from(kTableStaff).update({
            'fcm_token': token,
          }).eq(kStaffAuthUserId, user.id);
          debugPrint('[FCM] staff token update OK');
        } catch (e) {
          debugPrint('[FCM] staff token update FAILED: $e');
          rethrow;
        }
      } else {
        // Default to customer (covers owner/customer without pref).
        try {
          // Clear from staff first (token may be reused on same device).
          await Supabase.instance.client.from(kTableStaff).update({
            'fcm_token': null,
          }).eq('fcm_token', token);

          await Supabase.instance.client.from(kTableCustomers).update({
            kCustomersDeviceToken: token,
            'fcm_token': token,
          }).eq(kCustomersAuthUserId, user.id);
          debugPrint('[FCM] customer token update OK');
        } catch (e) {
          debugPrint('[FCM] customer token update FAILED: $e');
          rethrow;
        }
      }

      _lastSyncedToken = token;
      debugPrint('[FCM] token saved to Supabase (mode=${loginMode ?? 'customer'})');
    } catch (e) {
      debugPrint('[fcm_token] $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage msg) async {
    if (kIsWeb) return;
    await _ensureLocalNotificationsInitialized();

    final title = msg.notification?.title ?? 'Point';
    final body = msg.notification?.body ??
        (msg.data['body'] as String?) ??
        (msg.data['type'] != null ? 'لديك إشعار جديد' : 'Notification');

    final id = (msg.messageId ?? '${DateTime.now().millisecondsSinceEpoch}')
        .hashCode;

    await _flutterLocalNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'point_channel',
          'Point Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(msg.data),
    );
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
