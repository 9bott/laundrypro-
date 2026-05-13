import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/pinned_http_client.dart';

/// Central Supabase client accessor — call [init] before runApp after secrets load.
///
/// Uses default [FlutterAuthClientOptions]: SharedPreferences session persistence
/// (`sb-<project-ref>-auth-token`) and `autoRefreshToken: true`.
///
/// Certificate Pinning: injects a custom [httpClient] that trusts only the
/// ISRG Root X1 CA (Let's Encrypt), preventing MITM attacks even if a rogue CA
/// is installed on the device.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init({
    required String url,
    required String anonKey,
  }) {
    return Supabase.initialize(
      url: url,
      anonKey: anonKey,
      httpClient: createPinnedHttpClient(),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
    );
  }
}
