# Clean Architecture + MVVM

Bu proje, bağımlılık yönünü “presentation → domain → data” olacak şekilde kurgular; UI (View) yalnızca ViewModel’i dinler, iş kuralları domain katmanında kalır.

## Katmanlar
### Presentation (UI + MVVM)
- View: Flutter widget’ları
- ViewModel: `ChangeNotifier` tabanlı state + aksiyonlar
- Navigation: `AppRouter` üzerinden route’lar

### Domain (iş kuralları)
- Entity: saf modeller (örn. `Catalog`, `CatalogItem`)
- Repository (interface): veri kaynağından bağımsız kontrat
- Use case: tek sorumluluk iş aksiyonları (örn. `WatchCatalogs`, `CreateCatalog`)

### Data (uygulama içi entegrasyon)
- Repository implementation: domain arayüzünü gerçekler
- Data source: local/remote storage (şimdilik in-memory)

## Proje klasör yapısı (lib)
- `lib/app/`
  - `app.dart`: MaterialApp
  - `app_scope.dart`: bağımlılık erişimi (InheritedWidget)
  - `router/`: route tanımları
  - `theme/`: tema
- `lib/core/`: ortak tipler
- `lib/features/`
  - `catalog/`
    - `domain/`
    - `data/`
    - `presentation/`
  - `premium/`
  - `settings/`

## Bağımlılık yönetimi
Şu an ek paket kullanmadan `AppScope` ile bağımlılık sağlanır:
- `AppScope` içinde repository singleton’ları tutulur
- ViewModel’ler ilgili repository/use case’leri constructor üzerinden alır

## MVVM kural seti
- ViewModel UI widget’ı import etmez
- View yalnızca ViewModel’i dinler ve kullanıcı aksiyonlarını ViewModel’e iletir
- Domain entity’leri UI state olarak taşınabilir (MVP için)

## Mevcut MVP kapsamı
İlk ayağa kaldırma için:
- Katalog listesi
- Katalog editor (ürün listesi)
- Ürün ekle/düzenle
- Şablon seç
- Export & Share placeholder
- Paywall ve Settings placeholder

