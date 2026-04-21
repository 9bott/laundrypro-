import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/transaction_model.dart';
import '../../data/customer_repository.dart';
import 'customer_providers.dart';

class HistoryState {
  const HistoryState({
    required this.items,
    required this.hasMore,
    required this.filter,
    required this.page,
  });

  final List<TransactionModel> items;
  final bool hasMore;
  final String filter;
  final int page;

  static const empty = HistoryState(
    items: [],
    hasMore: false,
    filter: 'all',
    page: 0,
  );

  HistoryState copyWith({
    List<TransactionModel>? items,
    bool? hasMore,
    String? filter,
    int? page,
  }) {
    return HistoryState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
      page: page ?? this.page,
    );
  }
}

String? _typeFilterForApi(String chip) {
  switch (chip) {
    case 'purchase':
      return 'purchase';
    case 'redemption':
      return 'redemption';
    case 'subscription':
      return 'subscription';
    case 'rewards':
      return 'rewards';
    default:
      return null;
  }
}

bool _isRewardishType(String type) {
  switch (type) {
    case 'cashback_bonus':
    case 'referral_bonus':
    case 'streak_bonus':
    case 'birthday_bonus':
      return true;
    default:
      return false;
  }
}

TransactionModel _asCashbackOp(TransactionModel tx) {
  return TransactionModel(
    id: '${tx.id}:cashback',
    idempotencyKey: tx.idempotencyKey,
    customerId: tx.customerId,
    staffId: tx.staffId,
    type: 'cashback_earned',
    amount: tx.cashbackEarned,
    cashbackEarned: 0,
    subscriptionUsed: 0,
    cashbackUsed: 0,
    balanceBeforeCashback: tx.balanceBeforeCashback,
    balanceBeforeSubscription: tx.balanceBeforeSubscription,
    balanceAfterCashback: tx.balanceAfterCashback,
    balanceAfterSubscription: tx.balanceAfterSubscription,
    notes: tx.notes,
    deviceId: tx.deviceId,
    isUndone: tx.isUndone,
    undoneAt: tx.undoneAt,
    undoneBy: tx.undoneBy,
    createdAt: tx.createdAt,
  );
}

class CustomerHistoryNotifier extends AsyncNotifier<HistoryState> {
  CustomerRepository get _repo => ref.read(customerRepositoryProvider);

  static const _customerIdTimeout = Duration(seconds: 12);

  @override
  Future<HistoryState> build() async {
    ref.watch(currentCustomerIdProvider.select((a) => a.asData?.value));
    try {
      return await _fetch(filter: 'all', page: 0, append: false);
    } catch (_) {
      return HistoryState.empty;
    }
  }

  Future<HistoryState> _fetch({
    required String filter,
    required int page,
    required bool append,
  }) async {
    String? cid;
    try {
      cid = await ref
          .read(currentCustomerIdProvider.future)
          .timeout(_customerIdTimeout, onTimeout: () => null);
      if (cid == null) {
        if (append) {
          final v = state.value;
          return HistoryState(
            items: v?.items ?? [],
            hasMore: false,
            filter: filter,
            page: v?.page ?? page,
          );
        }
        return HistoryState(
          items: [],
          hasMore: false,
          filter: filter,
          page: 0,
        );
      }

      final batch = await _repo.getTransactions(
        cid,
        typeFilter: _typeFilterForApi(filter),
        page: page,
      );

      final prev = append ? state.value?.items ?? [] : <TransactionModel>[];

      List<TransactionModel> displayBatch = batch;
      if (filter == 'rewards') {
        final out = <TransactionModel>[];
        for (final tx in batch) {
          if (tx.cashbackEarned > 0) {
            // For purchases and bonuses: show each cashback as its own operation amount.
            if (tx.type == 'purchase') {
              out.add(_asCashbackOp(tx));
            } else if (_isRewardishType(tx.type)) {
              out.add(tx.copyWith(amount: tx.cashbackEarned));
            } else {
              // Fallback: keep as-is but still show cashback amount.
              out.add(tx.copyWith(amount: tx.cashbackEarned));
            }
          } else if (_isRewardishType(tx.type)) {
            // Bonus row with 0 cashback? keep it to avoid disappearing.
            out.add(tx);
          }
        }
        displayBatch = out;
      }

      return HistoryState(
        items: append ? [...prev, ...displayBatch] : displayBatch,
        hasMore: batch.length == 20,
        filter: filter,
        page: page,
      );
    } catch (e) {
      if (append) {
        final v = state.value;
        if (v != null && v.items.isNotEmpty) {
          return v.copyWith(hasMore: false);
        }
      }
      return HistoryState(
        items: [],
        hasMore: false,
        filter: filter,
        page: 0,
      );
    }
  }

  Future<void> applyFilter(String filter) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _fetch(filter: filter, page: 0, append: false));
    } catch (_) {
      state = AsyncValue.data(HistoryState.empty.copyWith(filter: filter));
    }
  }

  Future<void> loadMore() async {
    final v = state.value;
    if (v == null || !v.hasMore) return;
    state = AsyncValue.data(
      await _fetch(filter: v.filter, page: v.page + 1, append: true),
    );
  }

  Future<void> refresh() async {
    final v = state.value;
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _fetch(filter: v?.filter ?? 'all', page: 0, append: false),
      );
    } catch (_) {
      state = AsyncValue.data(
        HistoryState.empty.copyWith(filter: v?.filter ?? 'all'),
      );
    }
  }
}

final customerHistoryProvider =
    AsyncNotifierProvider<CustomerHistoryNotifier, HistoryState>(
  CustomerHistoryNotifier.new,
);
