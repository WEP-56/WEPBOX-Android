# WEPBOX

WEPBOX is an Android-focused fork of [Hiddify App](https://github.com/hiddify/hiddify-app). It keeps the existing Flutter Android client and sing-box/Hiddify Core integration, while moving the app identity, Android package, release artifacts, and GitHub Actions flow to WEPBOX.

## Scope

- Primary target: Android APK/AAB.
- Future target: Windows may be kept as a possible extension path.
- Removed targets: iOS, macOS, Linux, Web, and Snap project files were removed to reduce maintenance noise.

## Android Releases

Release builds are produced by GitHub Actions when a tag matching `vX.Y.Z` is pushed. The workflow publishes:

- `WEPBOX-Android-universal.apk`
- `WEPBOX-Android-arm64.apk`
- `WEPBOX-Android-arm7.apk`
- `WEPBOX-Android-x86_64.apk`
- `WEPBOX-Android-market.aab`

Android signing is configured through repository secrets. See [docs/android-signing.md](./docs/android-signing.md).

## Attribution

This project is based on Hiddify App:

- Upstream: https://github.com/hiddify/hiddify-app
- License: [Hiddify Extended GNU GPL v3](./LICENSE.md)

Changes in this fork include Android package renaming, WEPBOX app naming, Android-only release workflow, release artifact renaming, signing documentation, and removal of unused platform/project files.
