import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifies [GoRouter] when Supabase auth session changes.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
