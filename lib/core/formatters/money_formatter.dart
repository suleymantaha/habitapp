String formatMoney({
  required double value,
  required String currencyCode,
}) {
  final isInt = value == value.roundToDouble();
  final text = isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text $currencyCode';
}

