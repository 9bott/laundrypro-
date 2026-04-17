import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/active_store_provider.dart';
import '../../data/customer_repository.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/models/subscription_plan_model.dart';
import '../../../../core/router/auth_refresh.dart';

export 'history_notifier.dart';
export '../../../auth/data/auth_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository.fromEnv();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRefreshProvider = Provider<AuthRefresh>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final notifier = AuthRefresh(client);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final authUserProvider = StreamProvider<User?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentUser;
  await for (final e in client.auth.onAuthStateChange) {
    yield e.session?.user;
  }
});

final currentCustomerIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(
    authUserProvider.select((a) => a.asData?.value?.id),
  );
  if (userId == null) return null;
  final activeStoreId = ref.watch(activeStoreProvider).asData?.value;
  if (activeStoreId == null || activeStoreId.isEmpty) {
    // Without an active store, don't guess a random customer row.
    return null;
  }
  return ref
      .read(customerRepositoryProvider)
      .getCustomerIdForAuthUserInStore(userId, activeStoreId);
});

/// Live customer row (balances, tier, …) via Realtime.
final customerStreamProvider =
    StreamProvider.autoDispose<CustomerModel?>((ref) async* {
  ref.keepAlive();
  final id = await ref.watch(currentCustomerIdProvider.future);
  if (id == null) {
    yield null;
    return;
  }
  yield* ref.read(customerRepositoryProvider).watchCustomer(id);
});

final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  ref.keepAlive();
  // إذا Supabase غير مفعّل في البيئة، اعرض باقات افتراضية.
  if (!Env.hasSupabase) {
    return const [
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
  }
  final activeStoreId = ref.watch(activeStoreProvider).asData?.value;
  if (activeStoreId == null || activeStoreId.isEmpty) {
    return const [
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
  }
  return ref.read(customerRepositoryProvider).getSubscriptionPlans(storeId: activeStoreId);
});

final referralStatsProvider =
    FutureProvider.autoDispose<({int referredPeople, double referralEarnings})>(
  (ref) async {
    final id = await ref.watch(currentCustomerIdProvider.future);
    if (id == null) {
      return (referredPeople: 0, referralEarnings: 0.0);
    }
    return ref.read(customerRepositoryProvider).referralStats(id);
  },
);
