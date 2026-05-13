import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_check_service.dart';
import 'supabase_service.dart';

/// Wraps [FunctionsClient.invoke] and automatically injects the
/// Firebase App Check token as `X-Firebase-AppCheck` header.
///
/// Use instead of calling `client.functions.invoke(...)` directly.
abstract final class SecureFunctions {
  static Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    HttpMethod method = HttpMethod.post,
  }) async {
    final appCheckHeaders = await AppCheckService.headers();
    final mergedHeaders = {
      ...appCheckHeaders,
      if (headers != null) ...headers,
    };

    return SupabaseService.client.functions.invoke(
      functionName,
      headers: mergedHeaders,
      body: body,
      method: method,
    );
  }
}
