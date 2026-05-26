# Stellar Release Notes

Stellar builds desktop and mobile native targets from repository-owned IR:

- Desktop IR: `app-blueprint/app.ir.yaml`
- Mobile IR: `stellar-mobile/app-blueprint/mobile.ir.yaml`

GitHub Actions builds all release targets in `.github/workflows/native-release.yml`.

## Android

The Android app is direct-distribution first. The workflow always uploads
`stellar-android-debug-apk`, which contains `app-debug.apk`; that APK can be
downloaded from a GitHub Actions run and sideloaded on Android after enabling
installation from the browser or file manager used to open it.

The generated Android project has no Play Services dependency. Google Play
upload is manual and optional through the workflow dispatch input
`upload_play=true`. That path expects:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `ANDROID_SIGNING_KEYSTORE_BASE64`
- `ANDROID_SIGNING_STORE_PASSWORD`
- `ANDROID_SIGNING_KEY_ALIAS`
- `ANDROID_SIGNING_KEY_PASSWORD`

## iOS

The workflow generates the iOS Xcode project, builds an unsigned simulator app,
and uploads both `stellar-ios-project` and `stellar-ios-simulator-app`. A directly
installable iPhone build still requires Apple signing material and an Apple
distribution path such as TestFlight, ad hoc, or enterprise signing; there is no
Android-style unsigned APK equivalent for ordinary iPhones.

## License

Stellar is dual-licensed under `OWL 3.1 OR AGPL-3.0-or-later`. AGPL use includes
the additional terms in `WIZARDRY_ADDENDUM.md`.
