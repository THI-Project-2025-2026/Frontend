import 'dart:math' as math;

/// Formats [value] using a fixed number of fraction digits, optionally
/// trimming trailing zeros for prettier UI output.
String formatNumber(
  num value, {
  int fractionDigits = 1,
  bool trimTrailingZeros = true,
}) {
  final fixed = value.toStringAsFixed(fractionDigits);
  if (!trimTrailingZeros || !fixed.contains('.')) {
    return fixed;
  }

  final trimmed = fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

/// Rounds [value] to [fractionDigits] without going through string parsing.
double roundToDigits(double value, {int fractionDigits = 3}) {
  if (fractionDigits <= 0) {
    return value.roundToDouble();
  }
  final scale = math.pow(10, fractionDigits).toDouble();
  return (value * scale).round() / scale;
}
