import 'env_config.dart';

/// Build with: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
abstract final class Env {
  static String get supabaseUrl => EnvConfig.supabaseUrl;
  static String get supabaseAnonKey => EnvConfig.supabaseAnonKey;
  static bool get hasSupabase => EnvConfig.hasSupabase;
}
