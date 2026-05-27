# Android signing

WEPBOX uses the existing Gradle signing flow in `android/app/build.gradle`.
GitHub Actions writes `android/release.keystore` and `android/key.properties`
from repository secrets before building release artifacts.

Add these secrets in GitHub repository settings:

- `ANDROID_SIGNING_KEY`: base64 encoded keystore file
- `ANDROID_SIGNING_STORE_PASSWORD`: keystore password
- `ANDROID_SIGNING_KEY_PASSWORD`: key password
- `ANDROID_SIGNING_KEY_ALIAS`: key alias

Example local keystore generation:

```bash
keytool -genkeypair -v -keystore release.keystore -alias wepbox -keyalg RSA -keysize 2048 -validity 10000
base64 -w 0 release.keystore
```

Use the base64 output as `ANDROID_SIGNING_KEY`. Keep the original keystore
private and backed up. Losing it prevents users from upgrading to future APKs
signed as the same Android app.
