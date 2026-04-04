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
