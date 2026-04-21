import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        _handlePayload(msg.data);
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePayload(initial.data);
        });
      }
    } catch (e) {
      debugPrint('[Firebase] skipped: $e');
    }
  }

  /// After customer login — persists token on `customers.device_token`.
  static Future<void> syncCustomerDeviceToken(String? customerId) async {
    if (customerId == null) return;
    if (Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supabase.instance.client
          .from(kTableCustomers)
          .update({kCustomersDeviceToken: token})
          .eq(kCustomersId, customerId);
    } catch (e) {
      debugPrint('[fcm_token] $e');
    }
  }

  static void _handlePayload(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    final ctx = rootNavigatorKey.currentContext;
    if (route == null || ctx == null) return;
    try {
      GoRouter.of(ctx).go(route);
    } catch (e) {
      debugPrint('[fcm_nav] $e');
    }
  }
}
