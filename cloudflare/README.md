# Public Menü Servisi (Cloudflare Worker) Deploy

Bu klasördeki Worker, masa QR’ı okutulunca tarayıcıda menüyü açmak için kullanılır.

## Gerekenler

- Cloudflare hesabı
- Node.js (LTS)
- Wrangler CLI

## Kurulum

1) Wrangler kur

```bash
npm i -g wrangler
```

2) Cloudflare’a giriş yap

```bash
wrangler login
```

## Sık Hata: Authentication error (10000)

Eğer `wrangler kv ...` çalıştırınca şu tarz hata alırsan:

- `Authentication error [code: 10000]`
- `It looks like you have used Wrangler v1's config command...`

Sebep: Bilgisayarında Wrangler v1’den kalma eski token konfigürasyonu var ve Wrangler v4 bunu kullanmıyor.

Çözüm (önerilen, browser login):

1) Eski config dosyasını sil/yeniden adlandır:

- Windows yolu:
  - `C:\Users\<Kullanıcı>\AppData\Roaming\xdg.config\.wrangler\config\default.toml`

2) Yeniden giriş yap:

```bash
wrangler login
```

Çözüm (API token ile):

1) Cloudflare panelden yeni API token oluştur.
2) PowerShell’de env var olarak set et:

```powershell
$env:CLOUDFLARE_API_TOKEN="TOKEN_BURAYA"
```

Sonra komutları tekrar çalıştır.

## KV oluşturma

Worker menüleri Cloudflare KV’de tutar. Önce KV namespace oluştur:

```bash
wrangler kv namespace create MENUS
```

Komut çıktısında bir `id` göreceksin. Onu al ve [wrangler.toml](file:///c:/devops/habitapp/cloudflare/wrangler.toml) içindeki şu alanı güncelle:

```toml
kv_namespaces = [
  { binding = "MENUS", id = "REPLACE_WITH_KV_NAMESPACE_ID" }
]
```

Not: Bu `id`, sadece bu Worker’ı deploy eden Cloudflare hesabına aittir. Uygulamayı kullanan son kullanıcılar için sorun oluşturmaz; hepsi aynı Worker URL’ini kullanır ve menüler aynı KV içinde saklanır. Başka biri kendi hesabında deploy etmek isterse, kendi KV `id`’sini yazması gerekir.

## Deploy

Bu klasörde deploy et:

```bash
cd cloudflare
wrangler deploy
```

Deploy sonunda sana bir URL verir:

- `https://<worker-name>.<subdomain>.workers.dev`

## Uygulamaya bağlama

Uygulamada:

- Ayarlar → “Web menü servisi” alanına Worker URL’ini yapıştır → Kaydet

Sonra QR ekranına girince katalog otomatik publish edilir ve QR artık şu formata döner:

- `https://...workers.dev/m/<id>`

## Endpoint’ler

- `POST /api/menus` → yeni menü (id + editToken döner)
- `PUT /api/menus/:id` → menü güncelle (header: `x-edit-token`)
- `GET /m/:id` → müşteriye tarayıcıda menü HTML
- `GET /api/menus/:id` → menü JSON (debug)
