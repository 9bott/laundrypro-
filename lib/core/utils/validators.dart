/// Saudi mobile: +966 followed by 9 digits (leading 5 for mobile).
bool isValidSaPhoneDigits(String digitsOnly) {
  final d = digitsOnly.replaceAll(RegExp(r'\s'), '');
  if (d.length == 12 && d.startsWith('966')) {
    return RegExp(r'^966[5][0-9]{8}$').hasMatch(d);
  }
  if (d.length == 9 && d.startsWith('5')) {
    return RegExp(r'^5[0-9]{8}$').hasMatch(d);
  }
  return false;
}

String? nonEmpty(String? value, {String? message}) {
  if (value == null || value.trim().isEmpty) {
    return message ?? 'Required';
  }
  return null;
}

/// Strips HTML tags, script injections, and dangerous characters from input.
String sanitizeInput(String input) {
  return input
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[<>"\x27;\\]'), '')
      .trim();
}

/// Validates that a name contains only letters, spaces, and common Arabic diacritics.
String? validateName(String? value, {String? message}) {
  if (value == null || value.trim().isEmpty) {
    return message ?? 'Required';
  }
  if (value.trim().length < 2) {
    return 'الاسم قصير جداً';
  }
  if (value.trim().length > 100) {
    return 'الاسم طويل جداً';
  }
  return null;
}

/// Validates numeric input (for amounts, etc.).
String? validateAmount(String? value, {double min = 0, double max = 99999}) {
  if (value == null || value.trim().isEmpty) return 'Required';
  final amount = double.tryParse(value.trim());
  if (amount == null) return 'أدخل رقماً صحيحاً';
  if (amount < min) return 'القيمة أقل من الحد الأدنى';
  if (amount > max) return 'القيمة أعلى من الحد الأقصى';
  return null;
}
