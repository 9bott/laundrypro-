import 'package:intl/intl.dart';

/// SAR amount with Arabic-Indic digits when [arabicDigits] is true.
String formatMoneyAr(
  double amount, {
  bool arabicDigits = true,
  String locale = 'ar_SA',
}) {
  final fmt = NumberFormat.currency(
    locale: locale,
    name: 'SAR',
    symbol: '\u200Fر.س\u200F',
    decimalDigits: 2,
  );
  // Requirement: always show Western (English) digits across the app.
  // Keep params for API compatibility but do not convert digits.
  return fmt.format(amount);
}

String formatIntAr(int n, {bool arabicDigits = true}) {
  // Requirement: always show Western (English) digits across the app.
  // Keep param for API compatibility but do not convert digits.
  return '$n';
}
