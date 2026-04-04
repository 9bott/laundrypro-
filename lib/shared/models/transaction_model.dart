import '../../core/constants/supabase_constants.dart';
import 'model_parsing.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    this.idempotencyKey,
    required this.customerId,
    this.staffId,
    required this.type,
    required this.amount,
    required this.cashbackEarned,
    required this.subscriptionUsed,
    required this.cashbackUsed,
    this.balanceBeforeCashback,
    this.balanceBeforeSubscription,
    this.balanceAfterCashback,
    this.balanceAfterSubscription,
    this.notes,
    this.deviceId,
    required this.isUndone,
    this.undoneAt,
    this.undoneBy,
    required this.createdAt,
  });

  final String id;
  final String? idempotencyKey;
  final String customerId;
  final String? staffId;
  final String type;
  final double amount;
  final double cashbackEarned;
  final double subscriptionUsed;
  final double cashbackUsed;
  final double? balanceBeforeCashback;
  final double? balanceBeforeSubscription;
  final double? balanceAfterCashback;
  final double? balanceAfterSubscription;
  final String? notes;
  final String? deviceId;
  final bool isUndone;
  final DateTime? undoneAt;
  final String? undoneBy;
  final DateTime createdAt;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json[kTransactionsId]! as String,
      idempotencyKey: modelParseString(json[kTransactionsIdempotencyKey]),
      customerId:
          (json[kTransactionsCustomerId] ?? json[kTransactionsUserId] ?? '')
              as String,
      staffId: modelParseString(json[kTransactionsStaffId]),
      type: (json[kTransactionsType] as String?) ?? 'purchase',
      amount: modelParseDouble(json[kTransactionsAmount] ?? 0),
      cashbackEarned: modelParseDouble(json[kTransactionsCashbackEarned]),
      subscriptionUsed: modelParseDouble(json[kTransactionsSubscriptionUsed]),
      cashbackUsed: modelParseDouble(json[kTransactionsCashbackUsed]),
      balanceBeforeCashback: _nullableDouble(
        json[kTransactionsBalanceBeforeCashback],
      ),
      balanceBeforeSubscription: _nullableDouble(
        json[kTransactionsBalanceBeforeSubscription],
      ),
      balanceAfterCashback: _nullableDouble(
        json[kTransactionsBalanceAfterCashback],
      ),
      balanceAfterSubscription: _nullableDouble(
        json[kTransactionsBalanceAfterSubscription],
      ),
      notes: modelParseString(json[kTransactionsNotes]),
      deviceId: modelParseString(json[kTransactionsDeviceId]),
      isUndone: modelParseBool(json[kTransactionsIsUndone]),
      undoneAt: modelParseDateTime(json[kTransactionsUndoneAt]),
      undoneBy: modelParseString(json[kTransactionsUndoneBy]),
      createdAt: modelParseDateTime(json[kTransactionsCreatedAt])!,
    );
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    return modelParseDouble(value);
  }

  Map<String, dynamic> toJson() {
    return {
      kTransactionsId: id,
      kTransactionsIdempotencyKey: idempotencyKey,
      kTransactionsCustomerId: customerId,
      kTransactionsStaffId: staffId,
      kTransactionsType: type,
      kTransactionsAmount: amount,
      kTransactionsCashbackEarned: cashbackEarned,
      kTransactionsSubscriptionUsed: subscriptionUsed,
      kTransactionsCashbackUsed: cashbackUsed,
      kTransactionsBalanceBeforeCashback: balanceBeforeCashback,
      kTransactionsBalanceBeforeSubscription: balanceBeforeSubscription,
      kTransactionsBalanceAfterCashback: balanceAfterCashback,
      kTransactionsBalanceAfterSubscription: balanceAfterSubscription,
      kTransactionsNotes: notes,
      kTransactionsDeviceId: deviceId,
      kTransactionsIsUndone: isUndone,
      kTransactionsUndoneAt: undoneAt?.toUtc().toIso8601String(),
      kTransactionsUndoneBy: undoneBy,
      kTransactionsCreatedAt: createdAt.toUtc().toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? idempotencyKey,
    String? customerId,
    String? staffId,
    String? type,
    double? amount,
    double? cashbackEarned,
    double? subscriptionUsed,
    double? cashbackUsed,
    double? balanceBeforeCashback,
    double? balanceBeforeSubscription,
    double? balanceAfterCashback,
    double? balanceAfterSubscription,
    String? notes,
    String? deviceId,
    bool? isUndone,
    DateTime? undoneAt,
    String? undoneBy,
    DateTime? createdAt,
    bool clearIdempotencyKey = false,
    bool clearStaffId = false,
    bool clearBalanceBeforeCashback = false,
    bool clearBalanceBeforeSubscription = false,
    bool clearBalanceAfterCashback = false,
    bool clearBalanceAfterSubscription = false,
    bool clearNotes = false,
    bool clearDeviceId = false,
    bool clearUndoneAt = false,
    bool clearUndoneBy = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      idempotencyKey: clearIdempotencyKey
          ? null
          : (idempotencyKey ?? this.idempotencyKey),
      customerId: customerId ?? this.customerId,
      staffId: clearStaffId ? null : (staffId ?? this.staffId),
      type: type ?? this.type,
      amount: amount ?? this.amount,
      cashbackEarned: cashbackEarned ?? this.cashbackEarned,
      subscriptionUsed: subscriptionUsed ?? this.subscriptionUsed,
      cashbackUsed: cashbackUsed ?? this.cashbackUsed,
      balanceBeforeCashback: clearBalanceBeforeCashback
          ? null
          : (balanceBeforeCashback ?? this.balanceBeforeCashback),
      balanceBeforeSubscription: clearBalanceBeforeSubscription
          ? null
          : (balanceBeforeSubscription ?? this.balanceBeforeSubscription),
      balanceAfterCashback: clearBalanceAfterCashback
          ? null
          : (balanceAfterCashback ?? this.balanceAfterCashback),
      balanceAfterSubscription: clearBalanceAfterSubscription
          ? null
          : (balanceAfterSubscription ?? this.balanceAfterSubscription),
      notes: clearNotes ? null : (notes ?? this.notes),
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      isUndone: isUndone ?? this.isUndone,
      undoneAt: clearUndoneAt ? null : (undoneAt ?? this.undoneAt),
      undoneBy: clearUndoneBy ? null : (undoneBy ?? this.undoneBy),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
