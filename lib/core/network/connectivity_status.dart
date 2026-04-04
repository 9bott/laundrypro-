import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> r) =>
    r.any((e) => e != ConnectivityResult.none);

/// `true` when any connection is available.
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final plus = Connectivity();
  yield _isOnline(await plus.checkConnectivity());
  await for (final r in plus.onConnectivityChanged) {
    yield _isOnline(r);
  }
});
