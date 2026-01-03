import 'package:whatsapp_catalog/core/formatters/money_formatter.dart';

String buildCatalogShareText({
  required String catalogName,
  required List<CatalogShareItem> items,
  required String currencyCode,
}) {
  final buffer = StringBuffer()
    ..writeln(catalogName)
    ..writeln();
  if (items.isEmpty) {
    buffer.writeln('Menü yakında güncellenecek.');
  } else {
    buffer.writeln('Menü:');
    for (final item in items) {
      buffer.writeln(
        '- ${item.title} — ${formatMoney(value: item.price, currencyCode: currencyCode)}',
      );
    }
  }
  buffer
    ..writeln()
    ..writeln('Sipariş için bu mesajı yanıtlayabilirsin.');
  return buffer.toString().trim();
}

String buildWhatsAppSendUrl({required String text}) {
  final encoded = Uri.encodeComponent(text);
  return 'https://api.whatsapp.com/send?text=$encoded';
}

class CatalogShareItem {
  const CatalogShareItem({required this.title, required this.price});
  final String title;
  final double price;
}
