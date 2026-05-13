import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Returns a user-safe error message — strips internal exception details.
String safeErrorMessage(Object error, {String? arFallback, String? enFallback}) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return arFallback ?? enFallback ?? 'حدث خطأ. حاول مرة أخرى.';
  return arFallback ?? enFallback ?? 'حدث خطأ. حاول مرة أخرى.';
}
