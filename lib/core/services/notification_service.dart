import 'package:flutter/foundation.dart';
import 'package:pusher_beams/pusher_beams.dart';
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

    await PusherBeams.instance.start('1ae09655-a129-4f6c-b1a7-d943f815b992');

    // Subscribe the device to an interest.
    // - Per your server change, pushes will be published to `user-<customer_id>`.
    // - We also subscribe to `user-<auth_user_id>` as a fallback/debug channel.
    await _ensureBeamsInterestForCurrentUser();

    Supabase.instance.client.auth.onAuthStateChange.listen((_) async {
      await _ensureBeamsInterestForCurrentUser();
    });

    debugPrint('[Pusher] Initialized');
  }

  /// Backwards-compatible hook used by older call sites.
  /// With Pusher Beams, we subscribe the device to an interest based on customer id.
  static Future<void> syncCustomerDeviceToken(String? customerId) async {
    if (customerId == null) return;
    try {
      await PusherBeams.instance.addDeviceInterest('user-$customerId');
    } catch (e) {
      debugPrint('[Pusher] add interest failed: $e');
    }
  }

  static Future<void> _ensureBeamsInterestForCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await PusherBeams.instance.addDeviceInterest('user-${user.id}');

      // Best-effort: also subscribe to `user-<customers.id>` if this is a customer login.
      final prefs = await SharedPreferences.getInstance();
      final loginMode = prefs.getString(kLoginModePrefKey);
      if (loginMode != kLoginModeStaff) {
        final row = await Supabase.instance.client
            .from(kTableCustomers)
            .select(kCustomersId)
            .eq(kCustomersAuthUserId, user.id)
            .maybeSingle();
        final customerId = row?[kCustomersId] as String?;
        if (customerId != null && customerId.isNotEmpty) {
          await PusherBeams.instance.addDeviceInterest('user-$customerId');
        }
      }
    } catch (e) {
      debugPrint('[Pusher] init interest failed: $e');
    }
  }

  // NOTE: With Pusher Beams, notification click handling is configured natively
  // (or via deep links) rather than via an SDK click listener here.
}
