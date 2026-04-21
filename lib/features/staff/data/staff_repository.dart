import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';

class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.branch,
    this.pinHash,
    required this.isActive,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String branch;
  final String? pinHash;
  final bool isActive;

  factory StaffMember.fromRow(Map<String, dynamic> m) {
    return StaffMember(
      id: m[kStaffId] as String,
      name: m[kStaffName] as String,
      phone: m[kStaffPhone] as String,
      role: m[kStaffRole] as String? ?? 'staff',
      branch: m[kStaffBranch] as String? ?? 'main',
      pinHash: m[kStaffPinHash] as String?,
      isActive: m[kStaffIsActive] as bool? ?? true,
    );
  }
}

/// Customer payload for staff UI (QR or phone).
class StaffCustomerView {
  const StaffCustomerView({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.cashbackBalance,
    required this.subscriptionBalance,
    required this.tier,
    this.activePlanName,
    this.activePlanNameAr,
    required this.visitCount,
    this.lastVisitDate,
    required this.phoneE164,
    this.totalSpent = 0,
    this.streakCount = 0,
    this.birthday,
    this.preferredLanguage,
    this.isBlocked = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final double cashbackBalance;
  final double subscriptionBalance;
  final String tier;
  final String? activePlanName;
  final String? activePlanNameAr;
  final int visitCount;
  final DateTime? lastVisitDate;
  final String phoneE164;
  final double totalSpent;
  final int streakCount;
  final DateTime? birthday;
  final String? preferredLanguage;
  final bool isBlocked;
  final DateTime? createdAt;

  double get totalWalletBalance => subscriptionBalance + cashbackBalance;

  factory StaffCustomerView.fromQrJson(Map<String, dynamic> m) {
    final vc = m['visit_count'];
    return StaffCustomerView(
      id: m['customer_id'] as String,
      name: m['name'] as String,
      avatarUrl: m['avatar_url'] as String?,
      cashbackBalance: _d(m['cashback_balance']),
      subscriptionBalance: _d(m['subscription_balance']),
      tier: m['tier'] as String? ?? 'bronze',
      activePlanName: m['active_plan_name'] as String?,
      activePlanNameAr: m['active_plan_name_ar'] as String?,
      visitCount: vc is int ? vc : int.tryParse('$vc') ?? 0,
      lastVisitDate: null,
      phoneE164: '',
      // Not always present in QR payload; will be merged from customer row when available.
      totalSpent: 0,
      streakCount: 0,
      birthday: null,
      preferredLanguage: null,
      isBlocked: false,
      createdAt: null,
    );
  }

  factory StaffCustomerView.fromCustomerRow(
    Map<String, dynamic> m, {
    required String phone,
  }) {
    return StaffCustomerView(
      id: m[kCustomersId] as String,
      name: m[kCustomersName] as String,
      avatarUrl: m[kCustomersAvatarUrl] as String?,
      cashbackBalance: _d(m[kCustomersCashbackBalance]),
      subscriptionBalance: _d(m[kCustomersSubscriptionBalance]),
      tier: m[kCustomersTier] as String? ?? 'bronze',
      activePlanName: m[kCustomersActivePlanName] as String?,
      activePlanNameAr: m[kCustomersActivePlanNameAr] as String?,
      visitCount: m[kCustomersVisitCount] as int? ?? 0,
      lastVisitDate: m[kCustomersLastVisitDate] != null
          ? DateTime.tryParse(m[kCustomersLastVisitDate] as String)
          : null,
      phoneE164: phone,
      totalSpent: _d(m[kCustomersTotalSpent]),
      streakCount: m[kCustomersStreakCount] as int? ?? 0,
      birthday: m[kCustomersBirthday] != null
          ? DateTime.tryParse(m[kCustomersBirthday] as String)
          : null,
      preferredLanguage: m[kCustomersPreferredLanguage] as String?,
      isBlocked: m[kCustomersIsBlocked] as bool? ?? false,
      createdAt: m[kCustomersCreatedAt] != null
          ? DateTime.tryParse(m[kCustomersCreatedAt] as String)
          : null,
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}

class StaffRepository {
  StaffRepository(this._client);

  final SupabaseClient _client;

  factory StaffRepository.fromEnv() => StaffRepository(SupabaseService.client);

  static Map<String, dynamic>? _parseFunctionsResponseMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      try {
        final d = jsonDecode(data);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  static String hashPinSha256(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compares PIN hash to [pinHash] stored in DB (lowercase hex SHA-256).
  bool pinMatchesStoredHash(StaffMember staff, String pin) {
    if (staff.pinHash == null || staff.pinHash!.isEmpty) return false;
    final h = hashPinSha256(pin);
    return h.toLowerCase() == staff.pinHash!.toLowerCase();
  }

  Future<bool> verifyPin(String staffId, String pin) async {
    final row = await _client
        .from(kTableStaff)
        .select()
        .eq(kStaffId, staffId)
        .maybeSingle();
    if (row == null) return false;
    final staff = StaffMember.fromRow(Map<String, dynamic>.from(row));
    return pinMatchesStoredHash(staff, pin);
  }

  Future<StaffCustomerView?> getCustomerById(String id) async {
    final row = await _client
        .from(kTableCustomers)
        .select()
        .eq(kCustomersId, id)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    return StaffCustomerView.fromCustomerRow(
      m,
      phone: m[kCustomersPhone] as String? ?? '',
    );
  }

  /// Possible [kStaffPhone] values in DB vs Supabase auth (E.164 variants).
  static List<String> _staffPhoneLookupCandidates(String? phone) {
    if (phone == null || phone.isEmpty) return const [];
    final raw = phone.trim();
    final out = <String>{raw};
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return out.toList();
    out.add(digits);
    out.add('+$digits');
    if (digits.startsWith('966') && digits.length >= 12) {
      final local = digits.substring(3);
      if (local.length == 9) out.add('+966$local');
    }
    if (digits.length == 9 && digits.startsWith('5')) {
      out.add('+966$digits');
    }
    return out.toList();
  }

  Future<StaffMember?> getStaffForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from(kTableStaff)
        .select()
        .eq(kStaffAuthUserId, user.id)
        .eq(kStaffIsActive, true)
        .maybeSingle();

    if (response != null) {
      return StaffMember.fromRow(Map<String, dynamic>.from(response));
    }

    final phone = user.phone;
    if (phone != null && phone.isNotEmpty) {
      for (final candidate in _staffPhoneLookupCandidates(phone)) {
        final byPhone = await _client
            .from(kTableStaff)
            .select()
            .eq(kStaffPhone, candidate)
            .eq(kStaffIsActive, true)
            .maybeSingle();

        if (byPhone != null) {
          final row = Map<String, dynamic>.from(byPhone);
          final staffId = row[kStaffId] as String;
          await _client
              .from(kTableStaff)
              .update({kStaffAuthUserId: user.id})
              .eq(kStaffId, staffId);
          return StaffMember.fromRow(row);
        }
      }
    }

    return null;
  }

  Future<StaffCustomerView> getCustomerByQr(String qrToken) async {
    // Ensure we send a fresh staff JWT; function will reject missing/expired tokens.
    final initialSession = _client.auth.currentSession;
    if (initialSession == null) {
      throw StaffApiException(401, 'missing_session', code: 'missing_session');
    }
    if (initialSession.isExpired) {
      try {
        await _client.auth.refreshSession();
      } catch (e) {
        throw StaffApiException(401, '$e', code: 'refresh_failed');
      }
    }
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StaffApiException(401, 'missing_access_token', code: 'missing_access_token');
    }

    late final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        kFnGetCustomerByQr,
        method: HttpMethod.post,
        headers: {
          'Authorization': 'Bearer $token',
        },
        body: {'qr_token': qrToken},
      );
    } catch (e) {
      throw StaffApiException(
        0,
        '$e',
        code: 'network_error',
      );
    }
    if (res.status != 200) {
      final m = _parseFunctionsResponseMap(res.data);
      final msg = m != null
          ? '${m['message'] ?? m['error'] ?? res.data}'
          : '${res.data}';
      final code = m?['error']?.toString();
      throw StaffApiException(res.status, msg, code: code);
    }
    final map = Map<String, dynamic>.from(res.data as Map);
    final v = StaffCustomerView.fromQrJson(map);
    final full = await _client
        .from(kTableCustomers)
        .select()
        .eq(kCustomersId, v.id)
        .maybeSingle();
    if (full == null) return v;
    final merged = StaffCustomerView.fromCustomerRow(
      Map<String, dynamic>.from(full),
      phone: full[kCustomersPhone] as String? ?? '',
    );
    return StaffCustomerView(
      id: merged.id,
      name: merged.name,
      avatarUrl: merged.avatarUrl,
      cashbackBalance: merged.cashbackBalance,
      subscriptionBalance: merged.subscriptionBalance,
      tier: merged.tier,
      activePlanName: merged.activePlanName ?? v.activePlanName,
      activePlanNameAr: merged.activePlanNameAr ?? v.activePlanNameAr,
      visitCount: merged.visitCount,
      lastVisitDate: merged.lastVisitDate,
      phoneE164: merged.phoneE164,
      totalSpent: merged.totalSpent,
      streakCount: merged.streakCount,
      birthday: merged.birthday,
      preferredLanguage: merged.preferredLanguage,
      isBlocked: merged.isBlocked,
      createdAt: merged.createdAt,
    );
  }

  /// Exact phone match +966XXXXXXXXX
  Future<List<StaffCustomerView>> getCustomerByPhone(String phoneE164) async {
    final rows = await _client
        .from(kTableCustomers)
        .select()
        .eq(kCustomersPhone, phoneE164);
    final list = rows as List;
    return list
        .map(
          (e) => StaffCustomerView.fromCustomerRow(
            Map<String, dynamic>.from(e as Map),
            phone: phoneE164,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> addPurchase({
    required String customerId,
    required String staffId,
    required double amount,
    required String idempotencyKey,
    String? deviceId,
  }) async {
    final res = await _client.functions.invoke(
      kFnAddPurchase,
      body: {
        'customer_id': customerId,
        'staff_id': staffId,
        'amount': amount,
        'idempotency_key': idempotencyKey,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
    _throwIfBad(res);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> redeemBalance({
    required String customerId,
    required String staffId,
    required double amount,
    required String idempotencyKey,
  }) async {
    final res = await _client.functions.invoke(
      kFnRedeemBalance,
      body: {
        'customer_id': customerId,
        'staff_id': staffId,
        'amount': amount,
        'idempotency_key': idempotencyKey,
      },
    );
    _throwIfBad(res);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> addSubscription({
    required String customerId,
    required String staffId,
    required String planId,
    required String idempotencyKey,
  }) async {
    final res = await _client.functions.invoke(
      kFnAddSubscription,
      body: {
        'customer_id': customerId,
        'staff_id': staffId,
        'plan_id': planId,
        'idempotency_key': idempotencyKey,
      },
    );
    _throwIfBad(res);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> undoTransaction({
    required String transactionId,
    required String staffId,
  }) async {
    final res = await _client.functions.invoke(
      kFnUndoTransaction,
      body: {
        'transaction_id': transactionId,
        'staff_id': staffId,
      },
    );
    _throwIfBad(res);
    return Map<String, dynamic>.from(res.data as Map);
  }

  void _throwIfBad(FunctionResponse res) {
    if (res.status >= 200 && res.status < 300) return;
    Map<String, dynamic>? m;
    if (res.data is Map) m = Map<String, dynamic>.from(res.data as Map);
    final msg = m?['message'] ?? m?['error'] ?? '${res.data}';
    final code = m?['error']?.toString();
    throw StaffApiException(res.status, '$msg', code: code);
  }
}

class StaffApiException implements Exception {
  StaffApiException(this.status, this.message, {this.code});

  final int status;
  final String message;
  final String? code;

  bool get isQrExpired =>
      code == 'qr_expired' ||
      message.contains('qr_expired') ||
      message.contains('QR code expired');

  @override
  String toString() => message;
}
