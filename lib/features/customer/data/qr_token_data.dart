class QrTokenData {
  final String token;
  final DateTime expiresAt;

  const QrTokenData({
    required this.token,
    required this.expiresAt,
  });

  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get isExpired => secondsRemaining <= 0;
}

/// فشل استدعاء Edge Function `generate-qr-token`.
class QrTokenFetchException implements Exception {
  const QrTokenFetchException({
    required this.status,
    required this.message,
    this.code = '',
  });

  final int status;
  final String message;
  final String code;

  /// غالباً سر توقيع QR غير مضبوط في أسرار الدوال (أي من الأسماء المدعومة).
  bool get isServerConfig =>
      status == 500 &&
      (code == 'config_error' ||
          code == 'server_config' ||
          message.toLowerCase().contains('supabase_jwt_secret') ||
          message.toLowerCase().contains('qr_jwt_secret') ||
          message.toLowerCase().contains('jwt_secret') ||
          message.toLowerCase().contains('sign_failed') ||
          message.toLowerCase().contains('qr secret not set'));

  bool get isAuth =>
      status == 401 ||
      status == 403 ||
      code == 'unauthorized' ||
      message == 'customer_not_linked' ||
      message.contains('invalid_jwt');

  @override
  String toString() => 'QrTokenFetchException($status, $code): $message';
}
