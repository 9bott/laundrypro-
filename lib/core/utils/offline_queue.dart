import '../staff/staff_offline_queue.dart';
export '../staff/staff_pending_tx.dart';

/// Unified entry for Hive-backed offline staff transaction queue.
/// Same backing store as [StaffOfflineQueue]; idempotency keys prevent duplicates on replay.
abstract final class OfflineQueue {
  static Future<void> init() => StaffOfflineQueue.instance.init();

  /// Number of transactions waiting to sync (shown as badge on staff scanner).
  static int pendingCount() {
    try {
      return StaffOfflineQueue.instance.pending().length;
    } catch (_) {
      return 0;
    }
  }
}
