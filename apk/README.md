# NEURAVID Aperçu — the complete demo app (Android)

Built automatically on GitHub by `.github/workflows/apk-demo.yml` (Actions → "APK de démonstration" → Run workflow, or any push to `apk/`).
The `.apk` is published under **Releases** (`apk-apercu-N`).

- Package `com.neuravid.apercu`, demo signing key: it installs **next to** the production app `com.neuravid.app`, never over it.
- It opens `https://karamo655.github.io/neuravid-app/demo.html`: the full demonstration (every module, every feature, sample data marked « Aperçu »), always the latest published version. Offline, the copy of `web/` embedded in the APK takes over.
- Camera, microphone and location are requested from Android when a module asks for them (`onPermissionRequest`, `permission_handler`).

**For Afaq:** this is a working base, not the production app. For production: package `com.neuravid.app`, your release key, your session (`NV_TOKEN`, `NV_USER`), the real API in `web/nv-config.js`, the sign-up flow ending on `NV_MODULE_Conditions.html?inscription=1`, store in-app purchases, push notifications. `flutter/neuravid_distant.dart` and `notes/` describe each point.
