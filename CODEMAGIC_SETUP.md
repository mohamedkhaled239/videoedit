# Codemagic setup for videoedit iOS

The workflow is `ios-app-store` in `codemagic.yaml`. It builds a signed IPA and
uploads it to App Store Connect without automatically submitting it for review.

## 1. Apple records

1. Create the explicit App ID `com.ksanew.videoedit` in Apple Developer.
2. Enable Push Notifications for that App ID if Firebase notifications will be
   used.
3. Create the app in App Store Connect with bundle ID `com.ksanew.videoedit`.
4. Copy its numeric Apple ID from App Information.
5. Complete App Privacy, age rating, category, support URL, privacy-policy URL,
   screenshots, and export-compliance answers in App Store Connect.

## 2. App Store Connect API key

Create a dedicated App Store Connect API key with **App Manager** access. In
Codemagic, add an environment-variable group named `appstore_credentials` with
these encrypted variables:

- `APP_STORE_CONNECT_PRIVATE_KEY`: full contents of the `.p8` key.
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: App Store Connect Key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect Issuer ID.
- `APP_STORE_APPLE_ID`: the app's numeric Apple ID (recommended).
- `IOS_ADMOB_APP_ID`: production iOS AdMob application ID (`ca-app-pub-...~...`).

Do not commit any of these values to the repository.

## 3. Firebase and ads

Before a production upload, register `com.ksanew.videoedit` as a new iOS app in
Firebase and add the downloaded `GoogleService-Info.plist` to the Runner target.
Also replace the Google Mobile Ads test application ID in
`ios/Runner/Info.plist` with the production iOS App ID if ads remain enabled.

## 4. Run

Add the repository to Codemagic, choose **Configuration file** mode, select the
`ios-app-store` workflow, and start a build. The generated IPA is preserved as
an artifact and uploaded to App Store Connect. Submission for TestFlight or App
Review remains manual by design.

