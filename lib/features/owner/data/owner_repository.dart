import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/models/transaction_model.dart';

double _metricDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _localTodayStartIso() {
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day).toIso8601String();
}

const Duration kOwnerQueryTimeout = Duration(seconds: 10);

class OwnerDashboardMetrics {
  const OwnerDashboardMetrics({
    required this.totalRevenue,
    required this.transactionCount,
    required this.newCustomers,
    required this.cashbackIssued,
    required this.subscriptionsSold,
  });

  final double totalRevenue;
  final int transactionCount;
  final int newCustomers;
  final double cashbackIssued;
  final double subscriptionsSold;

  factory OwnerDashboardMetrics.fromJson(Map<String, dynamic> m) {
    return OwnerDashboardMetrics(
      totalRevenue: _metricDouble(m['total_revenue']),
      transactionCount: m['transaction_count'] as int? ?? 0,
      newCustomers: m['new_customers'] as int? ?? 0,
      cashbackIssued: _metricDouble(m['cashback_issued']),
      subscriptionsSold: _metricDouble(m['subscriptions_sold']),
    );
  }
}

class ChartDayPoint {
  const ChartDayPoint({required this.date, required this.revenue});
  final String date;
  final double revenue;

  factory ChartDayPoint.fromJson(Map<String, dynamic> m) {
    return ChartDayPoint(
      date: m['date'] as String? ?? '',
      revenue: _metricDouble(m['revenue']),
    );
  }
}

class TopCustomerRow {
  const TopCustomerRow({
    required this.name,
    required this.totalSpent,
    required this.visitCount,
  });
  final String name;
  final double totalSpent;
  final int visitCount;

  factory TopCustomerRow.fromJson(Map<String, dynamic> m) {
    return TopCustomerRow(
      name: m['name'] as String? ?? '',
      totalSpent: _metricDouble(m['total_spent']),
      visitCount: m['visit_count'] as int? ?? 0,
    );
  }
}

class StaffActivityRow {
  const StaffActivityRow({
    required this.staffName,
    required this.transactionCount,
    required this.totalProcessed,
  });
  final String staffName;
  final int transactionCount;
  final double totalProcessed;

  factory StaffActivityRow.fromJson(Map<String, dynamic> m) {
    return StaffActivityRow(
      staffName: m['staff_name'] as String? ?? '',
      transactionCount: m['transaction_count'] as int? ?? 0,
      totalProcessed: _metricDouble(m['total_processed']),
    );
  }
}

/// Four headline stats for the owner dashboard (today + total customers).
class OwnerSimpleTodayStats {
  const OwnerSimpleTodayStats({
    required this.totalCustomers,
    required this.todayTransactionCount,
    required this.todaySalesTotal,
    required this.todayCashbackTotal,
  });

  final int totalCustomers;
  final int todayTransactionCount;
  final double todaySalesTotal;
  final double todayCashbackTotal;

  static const empty = OwnerSimpleTodayStats(
    totalCustomers: 0,
    todayTransactionCount: 0,
    todaySalesTotal: 0,
    todayCashbackTotal: 0,
  );
}

class OwnerDashboardData {
  const OwnerDashboardData({
    required this.today,
    required this.period,
    required this.topCustomers,
    required this.staffActivity,
    required this.staffActivityToday,
    required this.chart7d,
    required this.fraudAlertsCount,
  });

  final OwnerDashboardMetrics today;
  final OwnerDashboardMetrics period;
  final List<TopCustomerRow> topCustomers;
  final List<StaffActivityRow> staffActivity;
  final List<StaffActivityRow> staffActivityToday;
  final List<ChartDayPoint> chart7d;
  final int fraudAlertsCount;

  factory OwnerDashboardData.fromJson(Map<String, dynamic> m) {
    List<T> mapList<T>(dynamic x, T Function(Map<String, dynamic>) f) {
      if (x is! List) return [];
      return x.map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    }

    return OwnerDashboardData(
      today: OwnerDashboardMetrics.fromJson(
        Map<String, dynamic>.from(m['today'] as Map? ?? {}),
      ),
      period: OwnerDashboardMetrics.fromJson(
        Map<String, dynamic>.from(m['period'] as Map? ?? {}),
      ),
      topCustomers: mapList(m['top_customers'], TopCustomerRow.fromJson),
      staffActivity: mapList(m['staff_activity'], StaffActivityRow.fromJson),
      staffActivityToday:
          mapList(m['staff_activity_today'], StaffActivityRow.fromJson),
      chart7d: mapList(m['chart_7d'], ChartDayPoint.fromJson),
      fraudAlertsCount: m['fraud_alerts_count'] as int? ?? 0,
    );
  }
}

class TransactionListRow {
  TransactionListRow({
    required this.transaction,
    required this.customerName,
    required this.customerPhone,
    required this.staffName,
  });

  final TransactionModel transaction;
  final String customerName;
  final String customerPhone;
  final String? staffName;
}

class FraudFlagRow {
  FraudFlagRow({
    required this.id,
    required this.flagType,
    required this.staffId,
    required this.customerId,
    required this.transactionId,
    required this.createdAt,
    this.staffName,
    this.customerName,
    this.customerPhone,
    this.txAmount,
    this.txType,
  });

  final String id;
  final String flagType;
  final String? staffId;
  final String? customerId;
  final String? transactionId;
  final DateTime createdAt;
  final String? staffName;
  final String? customerName;
  final String? customerPhone;
  final double? txAmount;
  final String? txType;
}

class StaffDirectoryRow {
  StaffDirectoryRow({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.branch,
    required this.isActive,
    required this.txToday,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String branch;
  final bool isActive;
  final int txToday;
}

class OwnerRepository {
  OwnerRepository(this._client);

  final SupabaseClient _client;

  factory OwnerRepository.fromEnv() =>
      OwnerRepository(SupabaseService.client);

  Future<OwnerDashboardData> fetchDashboard({
    required String storeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final res = await _client.functions
          .invoke(
            kFnGetOwnerDashboard,
            body: {
              'store_id': storeId,
              'date_from': dateFrom.toUtc().toIso8601String(),
              'date_to': dateTo.toUtc().toIso8601String(),
            },
          )
          .timeout(kOwnerQueryTimeout);
      if (res.status != 200) {
        throw Exception('dashboard:${res.status}:${res.data}');
      }
      return OwnerDashboardData.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on TimeoutException {
      throw Exception('dashboard:timeout');
    }
  }

  /// Headline stats: total customers (count), today tx count, sales (purchase), cashback sum.
  Future<OwnerSimpleTodayStats> fetchSimpleTodayStats({
    required String storeId,
  }) async {
    Future<OwnerSimpleTodayStats> run() async {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final dayStart = '${todayStr}T00:00:00';

      var totalCustomers = 0;
      var txCount = 0;
      var sales = 0.0;
      var cashback = 0.0;

      try {
        final res = await _client
            .from(kTableCustomers)
            .select(kCustomersId)
            .eq(kCustomersStoreId, storeId)
            .count(CountOption.exact);
        totalCustomers = res.count;
      } catch (_) {}

      try {
        final rows = await _client
            .from(kTableTransactions)
            .select(
              '$kTransactionsAmount, $kTransactionsCashbackEarned, $kTransactionsType',
            )
            .eq(kTransactionsStoreId, storeId)
            .gte(kTransactionsCreatedAt, dayStart)
            .eq(kTransactionsIsUndone, false) as List<dynamic>;
        txCount = rows.length;
        for (final raw in rows) {
          final m = Map<String, dynamic>.from(raw as Map);
          cashback += _metricDouble(m[kTransactionsCashbackEarned]);
          if ((m[kTransactionsType] as String?) == 'purchase') {
            sales += _metricDouble(m[kTransactionsAmount]);
          }
        }
      } catch (_) {}

      return OwnerSimpleTodayStats(
        totalCustomers: totalCustomers,
        todayTransactionCount: txCount,
        todaySalesTotal: sales,
        todayCashbackTotal: cashback,
      );
    }

    try {
      return await run().timeout(kOwnerQueryTimeout);
    } on TimeoutException {
      return OwnerSimpleTodayStats.empty;
    }
  }

  /// Customers list (no join to `transactions`).
  Future<List<CustomerModel>> fetchCustomersDirectory({
    required String storeId,
    String? search,
    String? tier,
    bool dormantOnly = false,
  }) async {
    try {
      var q = _client.from(kTableCustomers).select().eq(kCustomersStoreId, storeId);

      if (search != null && search.trim().isNotEmpty) {
        final s = '%${search.trim()}%';
        q = q.or('$kCustomersName.ilike.$s,$kCustomersPhone.ilike.$s');
      }
      if (tier != null && tier.isNotEmpty && tier != 'all') {
        q = q.eq(kCustomersTier, tier);
      }

      final rows = await q
          .order(kCustomersCreatedAt, ascending: false)
          .timeout(kOwnerQueryTimeout) as List<dynamic>;

      final list = rows
          .map(
            (e) => CustomerModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      if (!dormantOnly) return list;

      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      return list.where((c) {
        final lv = c.lastVisitDate;
        if (lv == null) return true;
        return lv.isBefore(cutoff);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TransactionListRow>> fetchTransactionsPage({
    required String storeId,
    required int offset,
    required int limit,
    String? search,
    String? typeFilter,
    String? staffIdFilter,
    DateTime? from,
    DateTime? to,
  }) {
    return _fetchTransactionsFallback(
      storeId: storeId,
      offset: offset,
      limit: limit,
      search: search,
      typeFilter: typeFilter,
      staffIdFilter: staffIdFilter,
      from: from,
      to: to,
    );
  }

  Future<List<TransactionListRow>> _fetchTransactionsFallback({
    required String storeId,
    required int offset,
    required int limit,
    String? search,
    String? typeFilter,
    String? staffIdFilter,
    DateTime? from,
    DateTime? to,
  }) async {
    var q = _client.from(kTableTransactions).select().eq(kTransactionsStoreId, storeId);
    if (typeFilter != null && typeFilter.isNotEmpty) {
      q = q.eq(kTransactionsType, typeFilter);
    }
    if (staffIdFilter != null && staffIdFilter.isNotEmpty) {
      q = q.eq(kTransactionsStaffId, staffIdFilter);
    }
    if (from != null) {
      q = q.gte(kTransactionsCreatedAt, from.toUtc().toIso8601String());
    }
    if (to != null) {
      q = q.lte(kTransactionsCreatedAt, to.toUtc().toIso8601String());
    }
    final rows = await q
        .order(kTransactionsCreatedAt, ascending: false)
        .range(offset, offset + limit - 1) as List<dynamic>;
    final list = rows
        .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final cids = list.map((t) => t.customerId).toSet().toList();
    final sids = list.map((t) => t.staffId).whereType<String>().toSet().toList();

    final cMap = <String, Map<String, dynamic>>{};
    if (cids.isNotEmpty) {
      final cr = await _client
          .from(kTableCustomers)
          .select()
          .eq(kCustomersStoreId, storeId)
          .inFilter(kCustomersId, cids);
      for (final row in cr as List) {
        final map = Map<String, dynamic>.from(row as Map);
        cMap[map[kCustomersId] as String] = map;
      }
    }
    final sMap = <String, String>{};
    if (sids.isNotEmpty) {
      final sr =
          await _client
              .from(kTableStaff)
              .select('id, name')
              .eq(kStaffStoreId, storeId)
              .inFilter('id', sids);
      for (final row in sr as List) {
        final map = Map<String, dynamic>.from(row as Map);
        sMap[map['id'] as String] = map[kStaffName] as String? ?? '';
      }
    }

    String? searchNorm = search?.trim().isEmpty == true ? null : search?.trim();

    return list
        .map((t) {
          final c = cMap[t.customerId];
          final name = c?[kCustomersName] as String? ?? '—';
          final phone = c?[kCustomersPhone] as String? ?? '';
          final sn = t.staffId != null ? sMap[t.staffId!] : null;
          return TransactionListRow(
            transaction: t,
            customerName: name,
            customerPhone: phone,
            staffName: sn,
          );
        })
        .where((r) {
          if (searchNorm == null) return true;
          final q = searchNorm.toLowerCase();
          return r.customerName.toLowerCase().contains(q) ||
              r.customerPhone.contains(searchNorm);
        })
        .toList();
  }

  Future<List<CustomerModel>> fetchCustomers({
    required String storeId,
    String? search,
    String? tier,
    bool dormantOnly = false,
  }) async {
    var q = _client.from(kTableCustomers).select().eq(kCustomersStoreId, storeId);

    if (search != null && search.trim().isNotEmpty) {
      final s = '%${search.trim()}%';
      q = q.or('$kCustomersName.ilike.$s,$kCustomersPhone.ilike.$s');
    }
    if (tier != null && tier.isNotEmpty && tier != 'all') {
      q = q.eq(kCustomersTier, tier);
    }

    final rows = await q.order(kCustomersLastVisitDate, ascending: false)
        as List<dynamic>;

    final list = rows
        .map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (!dormantOnly) return list;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return list.where((c) {
      if (c.lastVisitDate == null) return true;
      return c.lastVisitDate!.isBefore(cutoff);
    }).toList();
  }

  Future<List<TransactionModel>> fetchCustomerTransactions({
    required String storeId,
    required String customerId,
  }) async {
    final rows = await _client
        .from(kTableTransactions)
        .select()
        .eq(kTransactionsStoreId, storeId)
        .eq(kTransactionsCustomerId, customerId)
        .order(kTransactionsCreatedAt, ascending: false)
        .limit(200) as List<dynamic>;
    return rows
        .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> adjustCustomerBalance({
    required String storeId,
    required String customerId,
    double deltaSubscription = 0,
    double deltaCashback = 0,
    required String reason,
  }) async {
    final res = await _client.functions.invoke(
      kFnOwnerAdjustBalance,
      body: {
        'store_id': storeId,
        'customer_id': customerId,
        'delta_subscription': deltaSubscription,
        'delta_cashback': deltaCashback,
        'reason': reason,
      },
    );
    if (res.status != 200) {
      throw Exception(_errMsg(res));
    }
  }

  Future<void> setCustomerBlocked({
    required String storeId,
    required String customerId,
    required bool blocked,
    String? reason,
  }) async {
    final res = await _client.functions.invoke(
      kFnOwnerSetBlocked,
      body: {
        'store_id': storeId,
        'customer_id': customerId,
        'is_blocked': blocked,
        if (reason != null) 'reason': reason,
      },
    );
    if (res.status != 200) throw Exception(_errMsg(res));
  }

  Future<List<StaffDirectoryRow>> fetchStaffDirectory({
    required String storeId,
  }) async {
    try {
      final staffRows = await _client
          .from(kTableStaff)
          .select()
          .eq(kStaffStoreId, storeId)
          .order(kStaffName)
          .timeout(kOwnerQueryTimeout) as List<dynamic>;
      final dayStartIso = _localTodayStartIso();
      final txRows = await _client
          .from(kTableTransactions)
          .select(kTransactionsStaffId)
          .eq(kTransactionsStoreId, storeId)
          .gte(kTransactionsCreatedAt, dayStartIso)
          .eq(kTransactionsIsUndone, false)
          .timeout(kOwnerQueryTimeout) as List<dynamic>;

      final counts = <String, int>{};
      for (final r in txRows) {
        final id =
            Map<String, dynamic>.from(r as Map)[kTransactionsStaffId] as String?;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }

      return staffRows.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m[kStaffId] as String;
        return StaffDirectoryRow(
          id: id,
          name: m[kStaffName] as String? ?? '',
          phone: m[kStaffPhone] as String? ?? '',
          role: m[kStaffRole] as String? ?? 'staff',
          branch: m[kStaffBranch] as String? ?? '',
          isActive: m[kStaffIsActive] as bool? ?? true,
          txToday: counts[id] ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TransactionListRow>> fetchStaffTransactions({
    required String storeId,
    required String staffId,
  }) async {
    final rows = await _client
        .from(kTableTransactions)
        .select()
        .eq(kTransactionsStoreId, storeId)
        .eq(kTransactionsStaffId, staffId)
        .order(kTransactionsCreatedAt, ascending: false)
        .limit(100) as List<dynamic>;
    final list = rows
        .map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final cids = list.map((t) => t.customerId).toSet().toList();
    final cMap = <String, CustomerModel>{};
    if (cids.isNotEmpty) {
      final cr = await _client
          .from(kTableCustomers)
          .select()
          .eq(kCustomersStoreId, storeId)
          .inFilter(kCustomersId, cids);
      for (final row in cr as List) {
        final c = CustomerModel.fromJson(Map<String, dynamic>.from(row as Map));
        cMap[c.id] = c;
      }
    }
    return list.map((t) {
      final c = cMap[t.customerId];
      return TransactionListRow(
        transaction: t,
        customerName: c?.name ?? '—',
        customerPhone: c?.phone ?? '',
        staffName: null,
      );
    }).toList();
  }

  Future<void> setStaffActive({
    required String storeId,
    required String staffId,
    required bool isActive,
  }) async {
    final res = await _client.functions.invoke(
      kFnOwnerStaffActive,
      body: {'store_id': storeId, 'staff_id': staffId, 'is_active': isActive},
    );
    if (res.status != 200) throw Exception(_errMsg(res));
  }

  Future<void> inviteStaff({
    required String storeId,
    required String phoneE164,
    required String name,
    String branch = 'main',
  }) async {
    final res = await _client.functions.invoke(
      kFnOwnerInviteStaff,
      body: {'store_id': storeId, 'phone': phoneE164, 'name': name, 'branch': branch},
    );
    if (res.status != 200) throw Exception(_errMsg(res));
  }

  Future<List<FraudFlagRow>> fetchFraudFlags({
    required String storeId,
  }) async {
    final rows = await _client
        .from(kTableFraudFlags)
        .select()
        .eq(kFraudFlagsStoreId, storeId)
        .eq(kFraudFlagsResolved, false)
        .order(kFraudFlagsCreatedAt, ascending: false) as List<dynamic>;

    final list = rows.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return FraudFlagRow(
        id: m[kFraudFlagsId] as String,
        flagType: m[kFraudFlagsFlagType] as String? ?? '',
        staffId: m[kFraudFlagsStaffId] as String?,
        customerId: m[kFraudFlagsCustomerId] as String?,
        transactionId: m[kFraudFlagsTransactionId] as String?,
        createdAt: DateTime.parse(m[kFraudFlagsCreatedAt] as String),
      );
    }).toList();

    final sids = list.map((f) => f.staffId).whereType<String>().toSet().toList();
    final cids = list.map((f) => f.customerId).whereType<String>().toSet().toList();
    final tids =
        list.map((f) => f.transactionId).whereType<String>().toSet().toList();

    final sn = <String, String>{};
    if (sids.isNotEmpty) {
      final sr = await _client
          .from(kTableStaff)
          .select('id, name')
          .eq(kStaffStoreId, storeId)
          .inFilter(kStaffId, sids);
      for (final row in sr as List) {
        final m = Map<String, dynamic>.from(row as Map);
        sn[m['id'] as String] = m[kStaffName] as String? ?? '';
      }
    }
    final cn = <String, Map<String, String>>{};
    if (cids.isNotEmpty) {
      final cr = await _client
          .from(kTableCustomers)
          .select('id, name, phone')
          .eq(kCustomersStoreId, storeId)
          .inFilter(kCustomersId, cids);
      for (final row in cr as List) {
        final m = Map<String, dynamic>.from(row as Map);
        cn[m['id'] as String] = {
          'name': m[kCustomersName] as String? ?? '',
          'phone': m[kCustomersPhone] as String? ?? '',
        };
      }
    }
    final txi = <String, Map<String, dynamic>>{};
    if (tids.isNotEmpty) {
      final tr = await _client
          .from(kTableTransactions)
          .select('id, amount, type')
          .eq(kTransactionsStoreId, storeId)
          .inFilter(kTransactionsId, tids);
      for (final row in tr as List) {
        final m = Map<String, dynamic>.from(row as Map);
        txi[m['id'] as String] = m;
      }
    }

    return list.map((f) {
      final c = f.customerId != null ? cn[f.customerId!] : null;
      final tx = f.transactionId != null ? txi[f.transactionId!] : null;
      return FraudFlagRow(
        id: f.id,
        flagType: f.flagType,
        staffId: f.staffId,
        customerId: f.customerId,
        transactionId: f.transactionId,
        createdAt: f.createdAt,
        staffName: f.staffId != null ? sn[f.staffId!] : null,
        customerName: c?['name'],
        customerPhone: c?['phone'],
        txAmount: tx != null ? _metricDouble(tx['amount']) : null,
        txType: tx?['type'] as String?,
      );
    }).toList();
  }

  Future<void> resolveFraudFlag({
    required String storeId,
    required String flagId,
    required String action,
    String? notes,
  }) async {
    final res = await _client.functions.invoke(
      kFnOwnerFraudResolve,
      body: {
        'store_id': storeId,
        'flag_id': flagId,
        'action': action,
        if (notes != null) 'notes': notes,
      },
    );
    if (res.status != 200) throw Exception(_errMsg(res));
  }

  String _errMsg(FunctionResponse res) {
    if (res.data is Map) {
      final m = Map<String, dynamic>.from(res.data as Map);
      return '${m['message'] ?? m['error'] ?? res.data}';
    }
    return '${res.data}';
  }
}
