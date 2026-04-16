import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/models/subscription_plan_model.dart';
import '../../../shared/models/transaction_model.dart';
import 'qr_token_data.dart';

class CustomerRepository {
  CustomerRepository(this._client);

  final SupabaseClient _client;

  factory CustomerRepository.fromEnv() =>
      CustomerRepository(SupabaseService.client);

  static const List<SubscriptionPlanModel> _defaultPlans = [
    SubscriptionPlanModel(
      id: 'default-100',
      name: '100 SAR',
      nameAr: '١٠٠ ريال',
      price: 100,
      credit: 120,
      bonusPercentage: 20,
      isActive: true,
      sortOrder: 1,
    ),
    SubscriptionPlanModel(
      id: 'default-150',
      name: '150 SAR',
      nameAr: '١٥٠ ريال',
      price: 150,
      credit: 180,
      bonusPercentage: 20,
      isActive: true,
      sortOrder: 2,
    ),
    SubscriptionPlanModel(
      id: 'default-200',
      name: '200 SAR',
      nameAr: '٢٠٠ ريال',
      price: 200,
      credit: 250,
      bonusPercentage: 25,
      isActive: true,
      sortOrder: 3,
    ),
  ];

  Future<String?> getCustomerIdForAuthUser(String authUserId) async {
    final row = await _client
        .from(kTableCustomers)
        .select(kCustomersId)
        .eq(kCustomersAuthUserId, authUserId)
        .maybeSingle();
    return row?[kCustomersId] as String?;
  }

  Future<String?> getCustomerIdByPhone(String phoneE164) async {
    final row = await _client
        .from(kTableCustomers)
        .select(kCustomersId)
        .eq(kCustomersPhone, phoneE164)
        .maybeSingle();
    return row?[kCustomersId] as String?;
  }

  Future<CustomerModel?> getCustomer(String id) async {
    final row = await _client
        .from(kTableCustomers)
        .select()
        .eq(kCustomersId, id)
        .maybeSingle();
    if (row == null) return null;
    return CustomerModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Realtime updates for a single customer row (balances, tier, etc.).
  Stream<CustomerModel?> watchCustomer(String id) {
    return _client
        .from(kTableCustomers)
        .stream(primaryKey: [kCustomersId])
        .eq(kCustomersId, id)
        .map((rows) {
          if (rows.isEmpty) return null;
          return CustomerModel.fromJson(Map<String, dynamic>.from(rows.first));
        });
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> patch) async {
    await _client.from(kTableCustomers).update(patch).eq(kCustomersId, id);
  }

  /// Loads transactions for [customerId] and for the signed-in auth user ([kTransactionsUserId]),
  /// merges by row id, sorts by [kTransactionsCreatedAt] desc, then paginates in memory.
  Future<List<TransactionModel>> getTransactions(
    String customerId, {
    String? typeFilter,
    int page = 0,
    int pageSize = 20,
  }) async {
    final userId = _client.auth.currentUser?.id;

    Future<List<TransactionModel>> fetchByColumn(String column, String value) async {
      var query = _client.from(kTableTransactions).select().eq(column, value);

      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
        if (typeFilter == 'rewards') {
          query = query.or(
            '$kTransactionsType.eq.cashback_bonus,'
            '$kTransactionsType.eq.referral_bonus,'
            '$kTransactionsType.eq.streak_bonus,'
            '$kTransactionsType.eq.birthday_bonus,'
            // Include any row that earned cashback (usually purchases).
            '$kTransactionsCashbackEarned.gt.0',
          );
        } else {
          query = query.eq(kTransactionsType, typeFilter);
        }
      }

      final rows = await query.order(kTransactionsCreatedAt, ascending: false);
      return (rows as List)
          .map((e) {
            try {
              final model =
                  TransactionModel.fromJson(Map<String, dynamic>.from(e as Map));
              return model;
            } catch (err, stack) {
              if (kDebugMode) {
                debugPrint('[TX PARSE ERROR] $err');
                debugPrint('[TX RAW ROW] ${Map<String, dynamic>.from(e as Map)}');
                debugPrint('[TX STACK] $stack');
              }
              return null;
            }
          })
          .whereType<TransactionModel>()
          .toList();
    }

    final byCustomerId = await fetchByColumn(kTransactionsCustomerId, customerId);
    final byUserId = userId != null && userId.isNotEmpty
        ? await fetchByColumn(kTransactionsUserId, userId)
        : <TransactionModel>[];

    final merged = <String, TransactionModel>{};
    for (final t in [...byCustomerId, ...byUserId]) {
      merged[t.id] = t;
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final start = page * pageSize;
    final endExclusive = (start + pageSize).clamp(0, list.length);
    if (start >= endExclusive) return [];
    return list.sublist(start, endExclusive);
  }

  Future<List<SubscriptionPlanModel>> getSubscriptionPlans() async {
    try {
      final rows = await _client
          .from(kTableSubscriptionPlans)
          .select()
          .eq(kSubscriptionPlansIsActive, true)
          .order(kSubscriptionPlansSortOrder);
      final list = (rows as List)
          .map(
            (e) => SubscriptionPlanModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      // إذا لم توجد باقات في قاعدة البيانات، نستخدم باقات افتراضية لضمان ظهور الصفحة.
      return list.isEmpty ? _defaultPlans : list;
    } catch (_) {
      // في حال فشل الوصول (RLS/شبكة)، اعرض باقات افتراضية بدلاً من صفحة فارغة.
      return _defaultPlans;
    }
  }

  Future<QrTokenData> invokeGenerateQrToken() async {
    late final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        kFnGenerateQrToken,
        method: HttpMethod.post,
      );
    } on FunctionException catch (e) {
      final details = _parseFunctionsErrorBody(e.details);
      final msg = details?['message']?.toString() ??
          details?['error']?.toString() ??
          'Function failed (${e.status})';
      final code = details?['error']?.toString() ?? 'function_exception';
      throw QrTokenFetchException(
        status: e.status,
        code: code,
        message: msg.isEmpty ? 'function_exception:${e.status}' : msg,
      );
    } catch (e) {
      throw QrTokenFetchException(
        status: 0,
        code: 'network_error',
        message: '$e',
      );
    }
    if (res.status != 200) {
      final parsed = _parseFunctionsErrorBody(res.data);
      final msg = parsed?['message']?.toString() ??
          parsed?['error']?.toString() ??
          '${res.data}';
      final code = parsed?['error']?.toString() ?? '';
      throw QrTokenFetchException(
        status: res.status,
        code: code,
        message: msg.isEmpty ? 'http_${res.status}' : msg,
      );
    }
    final map = Map<String, dynamic>.from(res.data as Map);
    return QrTokenData(
      token: map['qr_token'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }

  static Map<String, dynamic>? _parseFunctionsErrorBody(dynamic data) {
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  Future<String> invokeGenerateGoogleWalletUrl() async {
    late final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        kFnGenerateGoogleWalletUrl,
        method: HttpMethod.post,
      );
    } on FunctionException catch (e) {
      final details = _parseFunctionsErrorBody(e.details);
      final msg = details?['message']?.toString() ??
          details?['error']?.toString() ??
          'Function failed (${e.status})';
      if (kDebugMode) debugPrint('[GoogleWallet] FunctionException: $msg');
      throw Exception('google_wallet_fn_error:${e.status}:$msg');
    }
    if (res.status != 200) {
      if (kDebugMode) debugPrint('[GoogleWallet] status=${res.status} body=${res.data}');
      throw Exception('google_wallet_url_failed:${res.status}:${res.data}');
    }
    final map = Map<String, dynamic>.from(res.data as Map);
    final url = map['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('google_wallet_url_missing');
    }
    return url;
  }

  /// PassKit (Apple Wallet / رابط التوزيع): يعيد `applePassUrl` و`landingUrl`.
  Future<Map<String, dynamic>> invokeGeneratePasskitWalletUrls() async {
    late final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        kFnGeneratePasskitWalletUrl,
        method: HttpMethod.post,
      );
    } on FunctionException catch (e) {
      final details = _parseFunctionsErrorBody(e.details);
      final msg = details?['message']?.toString() ??
          details?['error']?.toString() ??
          'Function failed (${e.status})';
      if (kDebugMode) debugPrint('[AppleWallet] FunctionException: $msg');
      throw Exception('passkit_fn_error:${e.status}:$msg');
    }
    if (res.status != 200) {
      if (kDebugMode) debugPrint('[AppleWallet] status=${res.status} body=${res.data}');
      throw Exception('passkit_wallet_failed:${res.status}:${res.data}');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Count of customers this user referred + sum of referral bonuses (if any).
  Future<({int referredPeople, double referralEarnings})> referralStats(
    String customerId,
  ) async {
    final countRes = await _client
        .from(kTableCustomers)
        .select(kCustomersId)
        .eq(kCustomersReferredBy, customerId);

    final referred = (countRes as List).length;

    final bonusRows = await _client
        .from(kTableTransactions)
        .select(kTransactionsCashbackEarned)
        .eq(kTransactionsCustomerId, customerId)
        .eq(kTransactionsType, 'referral_bonus');

    double earnings = 0;
    for (final r in bonusRows as List) {
      earnings += num.parse('${r[kTransactionsCashbackEarned]}').toDouble();
    }

    return (referredPeople: referred, referralEarnings: earnings);
  }

  Future<String> uploadAvatarFile({
    required String customerId,
    required File file,
  }) async {
    final path = '$customerId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(kBucketProfilePhotos).upload(path, file);
    return _client.storage.from(kBucketProfilePhotos).getPublicUrl(path);
  }
}
