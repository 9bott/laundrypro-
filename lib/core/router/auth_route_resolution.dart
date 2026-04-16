import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// Post-OTP / cold-start routing from Supabase memberships + [kLoginModePrefKey].
/// Returns `null` when the caller should run legacy onboarding (e.g. customer name dialog).
Future<String?> resolveRouteAfterOtp() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return '/auth/phone';

  final smRes = await Supabase.instance.client
      .from('store_memberships')
      .select('role, store_id')
      .eq('user_id', user.id)
      .eq('status', 'active');

  final smList = ((smRes as List?) ?? const <dynamic>[])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final cmRes = await Supabase.instance.client
      .from('customer_store_memberships')
      .select('store_id')
      .eq('user_id', user.id);

  final cmList = ((cmRes as List?) ?? const <dynamic>[])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final staffStoreIds = smList.map((e) => '${e['store_id']}').toSet();
  final custStoreIds = cmList.map((e) => '${e['store_id']}').toSet();
  final allStores = {...staffStoreIds, ...custStoreIds};

  if (allStores.length > 1) {
    return '/store-selector';
  }

  if (smList.isNotEmpty) {
    final role = smList.first['role'] as String? ?? 'staff';
    if (role == 'owner' || role == 'manager') {
      return '/staff/dashboard';
    }
    if (role == 'staff') {
      return '/staff/scanner';
    }
  }

  if (cmList.isNotEmpty) {
    return '/customer/home';
  }

  final prefs = await SharedPreferences.getInstance();
  final loginMode = prefs.getString(kLoginModePrefKey) ?? kLoginModeCustomer;

  if (loginMode == kLoginModeStaff) {
    return '/onboarding/create-store';
  }
  return null;
}
