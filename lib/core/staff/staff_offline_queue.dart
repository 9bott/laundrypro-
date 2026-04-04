import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'staff_pending_tx.dart';

const _boxName = 'staff_offline_tx_v1';

/// Persists staff confirmations when offline; [processAll] replays when online.
class StaffOfflineQueue {
  StaffOfflineQueue._();

  static final StaffOfflineQueue instance = StaffOfflineQueue._();

  Box<String>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  Box<String> get box {
    final b = _box;
    if (b == null) {
      throw StateError('StaffOfflineQueue.init() not called');
    }
    return b;
  }

  Future<String> enqueue(StaffPendingTx tx) async {
    await init();
    final key = tx.idempotencyKey;
    await box.put(key, tx.encode());
    return key;
  }

  List<StaffPendingTx> pending() {
    if (_box == null) return [];
    return box.values.map(StaffPendingTx.decode).toList();
  }

  Future<void> remove(String idempotencyKey) async {
    await init();
    await box.delete(idempotencyKey);
  }

  Future<void> clear() async {
    await init();
    await box.clear();
  }
}

typedef StaffTxProcessor = Future<void> Function(StaffPendingTx tx);

/// Listens for connectivity and drains queue (register in app or staff scanner).
class StaffQueueSync extends ChangeNotifier {
  StaffQueueSync(this._processOne);

  final StaffTxProcessor _processOne;
  bool _busy = false;

  bool get isProcessing => _busy;

  Future<void> processAll() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final items = StaffOfflineQueue.instance.pending();
      for (final tx in items) {
        try {
          await _processOne(tx);
          await StaffOfflineQueue.instance.remove(tx.idempotencyKey);
        } catch (e) {
          debugPrint('[staff_queue] failed ${tx.idempotencyKey}: $e');
        }
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
