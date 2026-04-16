import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kActiveStoreIdPrefKey = 'active_store_id';

final activeStoreProvider =
    AsyncNotifierProvider<ActiveStoreNotifier, String?>(ActiveStoreNotifier.new);

class ActiveStoreNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kActiveStoreIdPrefKey);
  }

  Future<void> setActiveStoreId(String? storeId) async {
    final prefs = await SharedPreferences.getInstance();
    if (storeId == null || storeId.trim().isEmpty) {
      await prefs.remove(kActiveStoreIdPrefKey);
      state = const AsyncValue.data(null);
      return;
    }
    await prefs.setString(kActiveStoreIdPrefKey, storeId);
    state = AsyncValue.data(storeId);
  }
}

