# NEURAVID Aperçu — the complete demo app (Android)

Built automatically on GitHub by `.github/workflows/apk-demo.yml` (Actions → "APK de démonstration" → Run workflow, or any push to `apk/`).
The `.apk` is published under **Releases** (`apk-apercu-N`).

- Package `com.neuravid.apercu`, demo signing key: it installs **next to** the production app `com.neuravid.app`, never over it.
- It opens `https://karamo655.github.io/neuravid-app/demo.html`: the full demonstration (every module, every feature, sample data marked « Aperçu »), always the latest published version. Offline, the copy of `web/` embedded in the APK takes over.
- Camera, microphone and location are requested from Android when a module asks for them (`onPermissionRequest`, `permission_handler`).

**For Afaq:** this is a working base, not the production app. For production: package `com.neuravid.app`, your release key, your session (`NV_TOKEN`, `NV_USER`), the real API in `web/nv-config.js`, the sign-up flow ending on `NV_MODULE_Conditions.html?inscription=1`, store in-app purchases, push notifications. `flutter/neuravid_distant.dart` and `notes/` describe each point.

## The « Aperçu » flag (3 November 2026)

Every NEURAVID module turns its « Aperçu » demo OFF when it sees `window.flutter_inappwebview`: that is how a module knows it runs inside the production app, where only real server data may appear. This demo APK must show the demo, so its start script sets `window.NV_APERCU = true`, and the shared demo detector (`nv_demo.js` in every module, plus the home, Passeport, Réglages and Tableau) keeps the demo on when this flag is present. (`javaScriptBridgeEnabled: false` was tried first, but flutter_inappwebview 6.1.5 does not have it.) **Afaq: NEVER set `NV_APERCU` in the production app `com.neuravid.app`.**
