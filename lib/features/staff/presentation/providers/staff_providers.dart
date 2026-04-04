import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_status.dart';
import '../../../../core/staff/staff_offline_queue.dart';
import '../../../../core/utils/offline_pending_provider.dart';
import '../../../customer/presentation/providers/customer_providers.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../data/staff_repository.dart';
import '../staff_route_models.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository.fromEnv();
});

final staffMemberProvider = FutureProvider<StaffMember?>((ref) async {
  ref.keepAlive();
  return ref.read(staffRepositoryProvider).getStaffForCurrentUser();
});

final staffCustomerProvider =
    NotifierProvider<StaffCustomerNotifier, StaffCustomerView?>(
        StaffCustomerNotifier.new);

class StaffCustomerNotifier extends Notifier<StaffCustomerView?> {
  @override
  StaffCustomerView? build() => null;

  void select(StaffCustomerView? c) => state = c;
}

final staffTxnModeProvider =
    NotifierProvider<StaffTxnModeNotifier, StaffTxnMode?>(
        StaffTxnModeNotifier.new);

class StaffTxnModeNotifier extends Notifier<StaffTxnMode?> {
  @override
  StaffTxnMode? build() => null;

  void setMode(StaffTxnMode? m) => state = m;
}

final staffEntryAmountProvider =
    NotifierProvider<StaffEntryAmountNotifier, double>(
        StaffEntryAmountNotifier.new);

class StaffEntryAmountNotifier extends Notifier<double> {
  @override
  double build() => 0;

  void setAmount(double a) => state = a;
}

final staffSelectedPlanIdProvider =
    NotifierProvider<StaffSelectedPlanIdNotifier, String?>(
        StaffSelectedPlanIdNotifier.new);

class StaffSelectedPlanIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSelectedPlanId(String? id) => state = id;
}

/// Latest transactions for a given customer (used in staff customer details).
final staffCustomerTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, customerId) async {
  return ref.read(customerRepositoryProvider).getTransactions(
        customerId,
        page: 0,
        pageSize: 20,
      );
});

final staffOfflineSyncProvider = Provider<StaffQueueSync>((ref) {
  final sync = StaffQueueSync((tx) async {
    final repo = ref.read(staffRepositoryProvider);
    switch (tx.kind) {
      case 'add_purchase':
        await repo.addPurchase(
          customerId: tx.customerId,
          staffId: tx.staffId,
          amount: tx.amount ?? 0,
          idempotencyKey: tx.idempotencyKey,
          deviceId: tx.deviceId,
        );
        break;
      case 'redeem_balance':
        await repo.redeemBalance(
          customerId: tx.customerId,
          staffId: tx.staffId,
          amount: tx.amount ?? 0,
          idempotencyKey: tx.idempotencyKey,
        );
        break;
      case 'add_subscription':
        await repo.addSubscription(
          customerId: tx.customerId,
          staffId: tx.staffId,
          planId: tx.planId ?? '',
          idempotencyKey: tx.idempotencyKey,
        );
        break;
      default:
        throw UnsupportedError(tx.kind);
    }
  });
  ref.onDispose(() {
    sync.dispose();
  });
  return sync;
});

/// مسار تطبيق الموظفين (المالك/المدير يشتركان نفس المسار مع تبويبات إضافية).
String staffShellBasePath(StaffMember? staff) => '/staff';

String staffShellScannerPath(StaffMember? staff) => '/staff/scanner';

/// Uses current [staffMemberProvider] when available.
String staffShellScannerPathForRef(WidgetRef ref) {
  return ref.watch(staffMemberProvider).maybeWhen(
        data: (_) => '/staff/scanner',
        orElse: () => '/staff/scanner',
      );
}

void staffListenConnectivityDrain(WidgetRef ref) {
  ref.listen(connectivityStatusProvider, (prev, next) {
    if (next.asData?.value == true) {
      unawaited(() async {
        await ref.read(staffOfflineSyncProvider).processAll();
        bumpOfflinePendingBadge(ref);
      }());
    }
  });
}

/// Safe to call from `initState`/`dispose` (uses `listenManual`).
ProviderSubscription<AsyncValue<bool>> staffListenConnectivityDrainManual(
  WidgetRef ref,
) {
  return ref.listenManual(connectivityStatusProvider, (prev, next) {
    if (next.asData?.value == true) {
      unawaited(() async {
        await ref.read(staffOfflineSyncProvider).processAll();
        bumpOfflinePendingBadge(ref);
      }());
    }
  });
}
