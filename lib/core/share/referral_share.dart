import 'package:whatsapp_catalog/core/settings/app_settings.dart';

Future<String> buildReferralShareText() async {
  final url = await AppSettings.getShareAppUrl();
  const base =
      '1 dakikada WhatsApp sipariş kataloğu: menünü ekle → QR + Story görseli çıkart → müşterin QR okutup WhatsApp’tan sipariş versin.';
  if (url == null) {
    return '$base\n\nUygulamayı mağazada “WhatsApp Katalog” diye arat.';
  }
  return '$base\n\nÜcretsiz dene: $url';
}
