String buildCatalogShareText({
  required String catalogName,
  required List<CatalogShareItem> items,
  required String currencyCode,
}) {
  final buffer = StringBuffer();
  buffer.writeln(catalogName);
  buffer.writeln();
  if (items.isEmpty) {
    buffer.writeln('Menü yakında güncellenecek.');
  } else {
    buffer.writeln('Menü:');
    for (final item in items) {
      buffer.writeln('- ${item.title} — ${_formatMoney(item.price, currencyCode)}');
    }
  }
  buffer.writeln();
  buffer.writeln('Sipariş için bu mesajı yanıtlayabilirsin.');
  return buffer.toString().trim();
}

String buildWhatsAppSendUrl({required String text}) {
  final encoded = Uri.encodeComponent(text);
  return 'https://api.whatsapp.com/send?text=$encoded';
}

String _formatMoney(double value, String currencyCode) {
  final isInt = value == value.roundToDouble();
  final text = isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text $currencyCode';
}

class CatalogShareItem {
  const CatalogShareItem({required this.title, required this.price});
  final String title;
  final double price;
}

