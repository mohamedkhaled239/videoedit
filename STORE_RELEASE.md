# videoedit store release checklist

## Identifiers

- Display name: `videoedit`
- Android application ID: `com.ksanew.videoedit`
- Apple bundle ID: `com.ksanew.videoedit`

These identifiers become permanent after the first store release. Confirm that
`com.ksanew.videoedit` belongs to the publisher before creating store records.

## Required private configuration

1. Register Android package `com.ksanew.videoedit` in Firebase and replace
   `android/app/google-services.json` with the newly downloaded file.
2. Register Apple bundle ID `com.ksanew.videoedit` in Firebase, download
   `GoogleService-Info.plist`, and add it to the Runner target in Xcode.
3. Replace the Google Mobile Ads test application IDs in AndroidManifest.xml
   and Info.plist with the production Android and iOS AdMob application IDs.
4. Create an Android upload keystore and copy `android/key.properties.example`
   to `android/key.properties`, then fill in the private values.
5. In Xcode, select the publisher's Apple Developer Team and configure signing
   for the `Runner` target.

Never commit keystores, `key.properties`, certificates, or provisioning
profiles to source control.

## Validation commands

```text
flutter analyze
flutter test
flutter build appbundle --release
flutter build ipa --release
```

The IPA command must run on macOS with Xcode and valid Apple signing assets.
