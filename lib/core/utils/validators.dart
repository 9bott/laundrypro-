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
