# Onboarding

## Amaç
Kullanıcıyı 60 saniye içinde ilk katalog çıktısına götürmek.

## Giriş koşulları
- İlk kurulumdan sonra açılır.

## Ekran akışı
1. Value props (3 slayt)
2. İş türü seçimi (Category)
3. Katalog adı + WhatsApp numarası (opsiyonel)
4. İlk ürün/hizmet ekleme (minimum 1)
5. Şablon seçimine yönlendirme

## Bileşenler
- Primary CTA: “Kataloğu Oluştur”
- Secondary CTA: “Örnek Katalogu Gör”
- Input: catalogName
- Picker: businessCategory
- Input (opsiyonel): whatsappNumber (E.164 önerilir)

## Validasyon
- catalogName: 2–40 karakter
- whatsappNumber: boş olabilir; doluysa sadece rakam + ülke kodu normalize edilir

## Başarı kriteri
- Kullanıcı “Template Picker” ekranına ulaşır ve en az 1 item eklemiştir.

## Boş/edge durumlar
- Kullanıcı numara girmek istemezse: paylaşım ekranında sonradan eklenebilir.

