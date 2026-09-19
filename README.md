# fridge-mobil

Flutter mobile client for the **receipt-scanning & shared fridge inventory** app. Users photograph a grocery receipt, the backend parses it with Google Gemini, and the parsed items land in a shared household inventory.

Backend: **[fridge-monorepo](https://github.com/Emrullah10/fridge-monorepo)**

## Tech Stack

Flutter, Dart. Camera capture, custom design system components, account management.

## Getting started

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api
```

### Ortam değişkenleri (derleme zamanı)

Backend URL'i ve RevenueCat anahtarları `--dart-define` ile geçirilir
(bkz. `lib/core/config/app_env.dart`) — daha önce bir `.env` dosyasından
okunuyordu, ama bu dosya bir Flutter asset'i olduğu için her yayınlanan
APK/AAB'nin içine düz metin olarak gömülüyordu.

```bash
flutter run --release \
  --dart-define=API_BASE_URL=https://api-fridge.emrullahbozkurt.com/api \
  --dart-define=REVENUECAT_API_KEY=goog_... \
  --dart-define=REVENUECAT_API_KEY_IOS=appl_...

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api-fridge.emrullahbozkurt.com/api \
  --dart-define=REVENUECAT_API_KEY=goog_... \
  --dart-define=REVENUECAT_API_KEY_IOS=appl_...
```

**`API_BASE_URL` verilmezse `http://localhost:4000/api`'ye sessizce düşer**
(bkz. `AppEnv.apiBaseUrl` `defaultValue`) — Play'e yüklenecek bir AAB
alırken bu define'ı unutmak build'i kırmaz, ama kimsede çalışmayan bir
sürüm üretir. Release build almadan önce bu değerin gerçekten PROD
adresini işaret ettiğinden emin ol.

IDE'de tekrar tekrar CLI'a yazmak yerine run/debug configuration'ına
(VS Code `launch.json` → `args`, Android Studio → Run/Debug Configurations
→ Additional run args) bu `--dart-define` bayraklarını ekle.
