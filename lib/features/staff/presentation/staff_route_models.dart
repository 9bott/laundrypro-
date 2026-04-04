import '../data/staff_repository.dart';

enum StaffTxnMode { purchase, redeem, subscription }

class StaffSuccessPayload {
  const StaffSuccessPayload({
    required this.transactionId,
    required this.mode,
    required this.response,
    required this.customer,
    required this.amount,
    this.subscriptionUsed,
    this.cashbackUsed,
  });

  final String transactionId;
  final StaffTxnMode mode;
  final Map<String, dynamic> response;
  final StaffCustomerView customer;
  final double amount;
  final double? subscriptionUsed;
  final double? cashbackUsed;
}
