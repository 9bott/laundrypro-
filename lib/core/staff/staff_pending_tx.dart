import 'dart:convert';

/// Serialized staff-side transaction for Hive offline queue.
class StaffPendingTx {
  const StaffPendingTx({
    required this.kind,
    required this.idempotencyKey,
    required this.customerId,
    required this.staffId,
    this.amount,
    this.planId,
    required this.createdAtMillis,
    this.deviceId,
  });

  final String kind; // add_purchase | redeem_balance | add_subscription
  final String idempotencyKey;
  final String customerId;
  final String staffId;
  final double? amount;
  final String? planId;
  final int createdAtMillis;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'idempotency_key': idempotencyKey,
        'customer_id': customerId,
        'staff_id': staffId,
        'amount': amount,
        'plan_id': planId,
        'created_at_millis': createdAtMillis,
        'device_id': deviceId,
      };

  factory StaffPendingTx.fromJson(Map<String, dynamic> m) {
    return StaffPendingTx(
      kind: m['kind'] as String,
      idempotencyKey: m['idempotency_key'] as String,
      customerId: m['customer_id'] as String,
      staffId: m['staff_id'] as String,
      amount: (m['amount'] as num?)?.toDouble(),
      planId: m['plan_id'] as String?,
      createdAtMillis: m['created_at_millis'] as int,
      deviceId: m['device_id'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static StaffPendingTx decode(String raw) =>
      StaffPendingTx.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
