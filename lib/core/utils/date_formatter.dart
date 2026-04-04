import 'package:intl/intl.dart';

/// Gregorian dates for EN / AR locales.
String formatShortDate(DateTime date, {String localeName = 'ar_SA'}) {
  return DateFormat.yMMMd(localeName).format(date);
}

String formatDateTime(DateTime date, {String localeName = 'ar_SA'}) {
  return DateFormat.yMMMd(localeName).add_jm().format(date);
}
