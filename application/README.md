# NEURAVID — official app (Android and iOS)

Owner: Karamo Fanta Sacko. Built, signed and uploaded by GitHub Actions (`.github/workflows/application-officielle.yml`).
Karamo's step-by-step guide (French): `GUIDE.md`.

## What it is

A Flutter shell around the NEURAVID website, the same principle as `flutter/neuravid_distant.dart`. The source is `lib/main.dart`.

- It loads `SITE` + `DEPART` from `config.env` (passed with `--dart-define`) ; by default `https://www.neuravid.com/index.html`.
- Every screen update published to `web/` reaches the app with **no store release**. The API address lives in `web/nv-config.js`.
- `web/` is embedded as an offline fallback (`loadFile`, `NV_MODULES_BASE = './'`).
- **It never sets `NV_APERCU`.** Modules see `window.flutter_inappwebview`, so they stay in production mode: never demo data.
- Our hosts stay inside the app: `www.neuravid.com`, `neuravid.com` and `karamo655.github.io` (the old GitHub address now redirects to `www.neuravid.com`). Any other domain, and `mailto:` / `tel:` links, open outside the app (`url_launcher`).
- Camera and microphone:
  - Android requests them with `permission_handler`, then grants the page ;
  - on iOS, WKWebView shows the system prompt (usage strings are set in Info.plist).
- Identifier `com.neuravid.app` (Android applicationId and iOS bundle id) ; versionName from `config.env` ; build number = workflow run number.

## Current state (7 November 2026)

- **Latest build: `application-9`** (Releases). It opens `https://www.neuravid.com/index.html` and keeps the redirect from the old GitHub address inside the app (fixed: `application-8` opened the phone browser after the custom domain went live).
- `application-9` is a **trial build (« ESSAI »)**, signed with a throwaway key: test it on phones, **never upload it to Google Play**.
- The website is served by GitHub Pages at **www.neuravid.com**. Your servers are at **api.neuravid.com**.
- `web/nv-config.js` still has `api: ''`. We will set `api: 'https://api.neuravid.com'` together, once sign-up works end to end on your side (identity in the accounts service, home feeds, CORS: `NV_COMPTES_ORIGINES`, `NV_ACCUEIL_ORIGINES`, `NV_WEBAUTHN_ORIGINES` = `https://www.neuravid.com`, and `NV_RP_ID=www.neuravid.com`).
- Passkeys inside the app need `https://www.neuravid.com/.well-known/assetlinks.json` with the SHA-256 fingerprint of the **Play App Signing key** (shown in Play Console → Test and release → App integrity after the first upload). Send Karamo the fingerprint; the file is published with `web/`.

## Google Play — first release (starting 8 November 2026)

You were invited to the Play Console with app-level rights on NEURAVID only (testing tracks). Production release, account administration and financial data stay with Karamo.

1. **Signed build.** Karamo adds the four `ANDROID_*` secrets, then runs *Actions → Application officielle → Run workflow* (platforms: android). The release `application-N` must **not** be marked « ESSAI » and must contain `NEURAVID_pour_Google_Play_seulement.aab`.
2. **First upload, by hand** (Google requires it for a new app): Play Console → *Test and release → Testing → Internal testing → Create new release* → upload that `.aab` → accept **Play App Signing**.
   - **Important: the first upload fixes the upload key forever.** Only upload the `.aab` built by GitHub with Karamo's key. Never build or sign a Play bundle with your own key.
3. **Testers.** Add the internal testers' Gmail addresses, share the opt-in link, check install and update on real phones.
4. **App content** (Policy → App content), with Karamo:
   - Privacy policy: `https://www.neuravid.com/NV_MODULE_Conditions.html?doc=confidentialite`
   - App access: a reviewer test account (needs the real sign-in).
   - Ads: no ads.
   - Content rating: IARC questionnaire (user-generated content, user interaction, live video, digital purchases).
   - Target audience: 13 and over, not designed for children.
   - Data safety: account data, user content (videos, photos, messages), camera/microphone use, approximate location (home country), encrypted in transit, deletion on request.
   - Account deletion: the in-app path (Réglages → « Supprimer mon compte ») and a web URL where deletion can be requested.
5. **Closed testing.** If the Play account is a *personal* account created after November 2023, Google requires a closed test with at least 12 testers for 14 days in a row before production access can be requested. An *organisation* account (TENAGON GROUP, LLC) does not have this rule.
6. **Production** is published by Karamo once the real servers, sign-in and the reviewer account work.

After the first upload, every new version can be sent automatically as a draft: secret `PLAY_SERVICE_ACCOUNT_JSON` (a Google Cloud service account invited in the Play Console), then *Run workflow* with « envoyer » checked (track `internal` by default).

## Build pipeline

- **Flutter** `3.35.x` stable for Android (newer Flutter releases and their Android tooling reject `flutter_inappwebview`) ; the exact version is printed in the log.
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

## Native bridge (3 November 2026)

The modules hand some actions to the native app. The official app implements every one that does **not** need a server. Page side: `pont.js`, injected at document start and tested by `test/pont.test.js` (Playwright). Phone side: `lib/pont.dart`, tested by `test/pont_test.dart`, which runs in CI before every build.

**Page side (`pont.js`):**
- `window.NVLien.ouvrir('NV<id>', ctx)` opens a module: it stores `nv_ctx_<id>` and navigates (Player → Iris). Every module tries this first, so navigation is immediate.
- `window.NVTelecharger(blob, nom)` sends the file in 2 MB chunks to the `nvEnregistrer` handler. `<a download>` links to `blob:` / `data:` URLs go the same way (La Forge « Garder », the Events calendar).
- `navigator.share` (missing in Android WebView) is routed to the `nvPartager` handler. Sharing files is rejected with `NotSupportedError`, so the module uses its own fallback.
- `window.open` is routed to the `nvOuvrirLien` handler.

**Phone side, `nvEvent` handler:**
- `open_module` / `open`: wrapped `payload`, or Orbite's raw `{type, module, live}`. `target` (with or without the `NV` prefix), `module` or `url` are all accepted. The app loads the module only if the page has not moved after 700 ms (most modules leave on their own), so nothing loads twice.
- `module_close`: go back.
- `share_request` / `share`: share sheet.
- `share_video_file`: save to the gallery and return `{ok}`.
- `save_file` / `download_request`: save the file, then dispatch `nv:file_saved`.
- `download`: an https video is downloaded and saved.
- `open_url`: external browser. `open_link`: in the app for our host, external browser otherwise.
- `haptic` (`{force:'leger'|'moyen'}`, 5 November 2026): a short vibration when a hexagonal tile of the home page is touched (`HapticFeedback.selectionClick` / `mediumImpact`, at most one every 80 ms). Unknown forces are ignored.
- `report_submit`, `loyalty_chest_request`, `battle_*_request`: immediate honest answer through `NVReportConfirm` / `NVFideliteCoffre` / `NVBattleConfirm` `{idem, success:false, reason}` (« not available yet: servers not connected »), instead of a 15–20 s timeout. **When the servers exist, forward these to the server instead.**

**Other handlers:** `nvTelecharger` (the modules' own chunk protocol), `nvEnregistrer`, `nvPartager` and `nvOuvrirLien`.

**Saving:** videos and images go to the gallery (`gal`, album NEURAVID) ; other files go to the share sheet (`share_plus`). The same file sent twice within 10 s is saved once.

**Still to do, needs servers and native screens:** `login_required` → `NVSession`, verifications (phone, age, KYC), account requests, payments and in-app purchases, `push_subscribe` (FCM / APNs), `live_broadcast_request`, the Baobab `NVRoom*` functions, `qr_scan_request`. Until then, some modules display « l'application ouvre… » for these features.

## Still to do before public store submission (servers, not this shell)

- Real servers behind `web/nv-config.js`.
- A working sign-in / sign-up flow that ends with `NV_MODULE_Conditions.html?inscription=1`.
- A reviewer test account.
- In-app purchases through Apple / Google billing for digital goods (coins, gifts).
- Fill the `nvEvent` JavaScript handler in `lib/main.dart` if native events are needed (session, purchases).
