# Kod İnceleme Notları

Bu doküman, mevcut Flutter kod yapısının güçlü/zayıf yönlerini ve iyileştirme adımlarını kayıt eder.

## Genel durum
- Mimari: Clean Architecture (domain/data/presentation) + MVVM (ChangeNotifier) kurgusu var.
- DI: `AppScope` ile manuel bağımlılık sağlanıyor.
- Veri: `InMemoryCatalogRepository` ile MVP akışı çalışıyor.

## Tespit edilen sorunlar (ilk sürüm)
- Katalog oluşturma akışı “tek tıkla” katalog açtığı için yanlışlıkla çoklu katalog üretimi kolaydı.
- Home ve editor ekranları görsel olarak çok hamdı; modern Material 3 yüzey/spacing/CTA hiyerarşisi zayıftı.
- Katalog listesi sıralaması güncellenme zamanına göre stabilize değildi.
- Editor ekranında boş/az veri durumunda ekran “çok boş” hissi veriyordu; kullanıcıyı bir sonraki aksiyona yönlendirmiyordu.

## Yapılan iyileştirmeler
- Tema güçlendirildi: surface/container, card/input/button stilleri modernleştirildi.
- Katalog oluşturma: bottom sheet ile ad + para birimi seçimi eklendi.
- Home: kart tasarımı + empty state CTA + silme aksiyonu eklendi.
- Katalog listesi: `updatedAt`’e göre sıralama eklendi.
- Catalog editor: özet kart + paylaş CTA + ürün empty state ve kart listesi ile okunabilirlik artırıldı.
- Product editor: daha net form, AppBar’da güçlü CTA ve öğe silme eklendi.

## Açık kalan başlıklar (sonraki adımlar)
- Onboarding ekranı (kategori, WhatsApp numarası, mesaj şablonu) ve ilk paylaşım hedefi.
- Export & Share gerçek çıktı üretimi (Story/PDF/QR) ve paylaşım entegrasyonları.
- Kalıcı storage (local DB) + versiyonlama + migration.
- Premium/Paywall gerçek satın alma entegrasyonu.

