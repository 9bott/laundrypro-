import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Retrieves the current Firebase App Check token for attaching to
/// Edge Function requests via the `X-Firebase-AppCheck` header.
abstract final class AppCheckService {
  static Future<String?> getToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      debugPrint('[AppCheck] getToken failed: $e');
      return null;
    }
  }

  /// Returns headers map with App Check token if available.
  static Future<Map<String, String>> headers() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return const {};
    return {'X-Firebase-AppCheck': token};
  }
}
