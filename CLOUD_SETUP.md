# Cloud Setup

This app now supports real cloud connections for Google Drive and Dropbox.

## Build-time configuration

Pass credentials with `--dart-define` when running or building.

Example:

```powershell
flutter run ^
  --dart-define=GOOGLE_CLIENT_ID=your-google-android-client-id ^
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-google-web-client-id ^
  --dart-define=DROPBOX_CLIENT_ID=your-dropbox-app-key
```

For release builds use the same defines with `flutter build apk --release` or `flutter build appbundle --release`.

## Google Drive

Required define:
- `GOOGLE_CLIENT_ID` or `GOOGLE_SERVER_CLIENT_ID`

Setup notes:
- Android package name: `com.pdfediter.pro`
- If you already created an Android OAuth client in Google Cloud, use that as `GOOGLE_CLIENT_ID`.
- If you also create a Web OAuth client, you can pass it as `GOOGLE_SERVER_CLIENT_ID`.
- Add the app signing SHA-1 and SHA-256 fingerprints in Google Cloud / Firebase.
- Enable the Google Drive API.
- Scope used by the app: `https://www.googleapis.com/auth/drive.file`
- The app stores PDFs in a `PDF Editor Pro` folder created by the app.

## Dropbox

Required define:
- `DROPBOX_CLIENT_ID`

Setup notes:
- Redirect URI: `com.pdfediter.pro.auth://oauth/callback`
- Scopes:
  - `account_info.read`
  - `files.metadata.read`
- `files.content.read`
- `files.content.write`
- Enable refresh tokens / offline access in the Dropbox app settings.
- Files are stored in the app folder/root configured for the Dropbox app.
