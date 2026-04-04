import 'package:intl/intl.dart';

/// Saudi Riyal (SAR) display — uses locale-aware grouping; symbol varies by locale.
String formatSar(
  num amount, {
  String localeName = 'ar_SA',
  int minimumFractionDigits = 2,
  int maximumFractionDigits = 2,
}) {
  final fmt = NumberFormat.currency(
    locale: localeName,
    name: 'SAR',
    symbol: 'ر.س',
    decimalDigits: maximumFractionDigits,
  );
  return fmt.format(amount);
}
