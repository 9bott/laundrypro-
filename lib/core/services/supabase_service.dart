import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase client accessor — call [init] before runApp after secrets load.
///
/// Uses default [FlutterAuthClientOptions]: SharedPreferences session persistence
/// (`sb-<project-ref>-auth-token`) and `autoRefreshToken: true`.
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
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
    );
  }
}
