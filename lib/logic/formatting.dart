/// Formats [value] with a fixed number of decimals, e.g. 8.7 -> "8.7".
///
/// Used for headline figures, where a steady number of digits is easier to
/// read at a glance than a trimmed one.
String fixed(double value, [int decimals = 1]) {
  if (!value.isFinite) return '--';
  return value.toStringAsFixed(decimals);
}

/// Formats [value] and drops trailing zeros, e.g. 12.50 -> "12.5", 10.0 -> "10".
String trimmed(double value, [int decimals = 1]) {
  if (!value.isFinite) return '--';
  final String text = value.toStringAsFixed(decimals);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Parses user input, tolerating a comma decimal separator and stray spaces.
///
/// Returns null for anything that is not a finite number.
double? parseNumber(String? text) {
  if (text == null) return null;
  final String cleaned = text.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final double? value = double.tryParse(cleaned);
  if (value == null || !value.isFinite) return null;
  return value;
}
