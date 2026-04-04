import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_queue.dart';

final offlinePendingTickProvider =
    NotifierProvider<OfflinePendingNotifier, int>(OfflinePendingNotifier.new);

class OfflinePendingNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
  void decrement() => state > 0 ? state-- : state = 0;
  void reset() => state = 0;
  void set(int value) => state = value;
}

final offlinePendingCountProvider = Provider<int>((ref) {
  ref.watch(offlinePendingTickProvider);
  return OfflineQueue.pendingCount();
});

void bumpOfflinePendingBadge(WidgetRef ref) {
  ref.read(offlinePendingTickProvider.notifier).increment();
}
