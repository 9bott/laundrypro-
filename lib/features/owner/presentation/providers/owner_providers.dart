import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/active_store_provider.dart';
import '../../data/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository.fromEnv();
});

final ownerDashboardProvider =
    FutureProvider.family<OwnerDashboardData, ({DateTime from, DateTime to})>(
  (ref, range) {
    final repo = ref.watch(ownerRepositoryProvider);
    final storeId = ref.watch(activeStoreProvider).asData?.value;
    if (storeId == null || storeId.isEmpty) {
      throw Exception('missing_active_store');
    }
    return repo.fetchDashboard(storeId: storeId, dateFrom: range.from, dateTo: range.to);
  },
);

final ownerDateRangeProvider =
    NotifierProvider<OwnerDateRangeNotifier, (DateTime, DateTime)>(
        OwnerDateRangeNotifier.new);

class OwnerDateRangeNotifier extends Notifier<(DateTime, DateTime)> {
  @override
  (DateTime, DateTime) build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;
    return (start, end);
  }
}

final ownerStaffDirectoryProvider = FutureProvider((ref) async {
  final storeId = ref.watch(activeStoreProvider).asData?.value;
  if (storeId == null || storeId.isEmpty) return [];
  return ref.watch(ownerRepositoryProvider).fetchStaffDirectory(storeId: storeId);
});

/// Simple headline stats (total customers, today tx/sales/cashback).
final ownerTodayOverviewProvider =
    FutureProvider.autoDispose<OwnerSimpleTodayStats>((ref) {
  final repo = ref.watch(ownerRepositoryProvider);
  final storeId = ref.watch(activeStoreProvider).asData?.value;
  if (storeId == null || storeId.isEmpty) return OwnerSimpleTodayStats.empty;
  return repo.fetchSimpleTodayStats(storeId: storeId);
});
