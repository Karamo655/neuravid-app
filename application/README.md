# NEURAVID — official app (Android and iOS)

Owner: Karamo Fanta Sacko. Built, signed and uploaded by GitHub Actions (`.github/workflows/application-officielle.yml`).
Karamo's step-by-step guide (French): `GUIDE.md`.

## What it is

A Flutter shell around the NEURAVID website, the same principle as `flutter/neuravid_distant.dart`. The source is `lib/main.dart`.

- It loads `SITE` + `DEPART` from `config.env` (passed with `--dart-define`) ; by default `https://karamo655.github.io/neuravid-app/index.html`.
- Every screen update published to `web/` reaches the app with **no store release**. The API address lives in `web/nv-config.js`.
- `web/` is embedded as an offline fallback (`loadFile`, `NV_MODULES_BASE = './'`).
- **It never sets `NV_APERCU`.** Modules see `window.flutter_inappwebview`, so they stay in production mode: never demo data.
- External links (mailto, other domains) open outside the app (`url_launcher`).
- Camera and microphone:
  - Android requests them with `permission_handler`, then grants the page ;
  - on iOS, WKWebView shows the system prompt (usage strings are set in Info.plist).
- Identifier `com.neuravid.app` (Android applicationId and iOS bundle id) ; versionName from `config.env` ; build number = workflow run number.

## Build pipeline

- **Flutter** stable channel (the version is printed in the log).
- **Plugins:** `flutter_inappwebview ^6.1.5`, `permission_handler ^11.3.1`, `url_launcher ^6.3.0`.
- **Android:**
  - `compileSdk` / `targetSdk` 36 (Google Play requirement since 31 Aug 2026), `minSdk` 24 ;
  - signed from the secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` (Karamo's upload key ; Play App Signing holds the app signing key) ;
  - without these secrets, it builds with a throwaway key, marked as a pre-release « ESSAI ». That build is for testing only, never for Google Play ;
  - outputs `NEURAVID_installer_sur_le_telephone.apk` and (signed builds only) `NEURAVID_pour_Google_Play_seulement.aab`, published in Releases as `application-N` (a trial build has no .aab) ;
  - optional upload to Google Play as a draft (`r0adkll/upload-google-play`, secret `PLAY_SERVICE_ACCOUNT_JSON`). The first upload of a new app must be done by hand in the Play Console.
- **iOS** (macOS runner):
  - `flutter build ios --no-codesign`, then `xcodebuild archive` and `-exportArchive` with automatic cloud signing through an App Store Connect API key (Admin role) ;
  - secrets: `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8` ;
  - destination `upload` (TestFlight) when « envoyer » is checked, `export` otherwise ;
  - without these secrets, the job only compiles.

## Still to do before public store submission (servers, not this shell)

- Real servers behind `web/nv-config.js`.
- A working sign-in / sign-up flow that ends with `NV_MODULE_Conditions.html?inscription=1`.
- A reviewer test account.
- In-app purchases through Apple / Google billing for digital goods (coins, gifts).
- Fill the `nvEvent` JavaScript handler in `lib/main.dart` if native events are needed (session, purchases).
