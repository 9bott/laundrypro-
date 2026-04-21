import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository.fromEnv();
});

final ownerDashboardProvider =
    FutureProvider.family<OwnerDashboardData, ({DateTime from, DateTime to})>(
  (ref, range) {
    final repo = ref.watch(ownerRepositoryProvider);
    return repo.fetchDashboard(dateFrom: range.from, dateTo: range.to);
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
  return ref.watch(ownerRepositoryProvider).fetchStaffDirectory();
});

/// Simple headline stats (total customers, today tx/sales/cashback).
final ownerTodayOverviewProvider =
    FutureProvider.autoDispose<OwnerSimpleTodayStats>((ref) {
  final repo = ref.watch(ownerRepositoryProvider);
  return repo.fetchSimpleTodayStats();
});
