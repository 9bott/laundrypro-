/// Shared JSON ↔ typed values for PostgREST / Supabase rows.
double modelParseDouble(Object? value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int modelParseInt(Object? value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool modelParseBool(Object? value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return fallback;
}

DateTime? modelParseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String? modelParseString(Object? value) {
  if (value == null) return null;
  return value.toString();
}
