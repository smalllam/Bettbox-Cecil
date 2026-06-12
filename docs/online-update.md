# Online update

The white-label client can check a provider-hosted JSON manifest and download a
new Android APK or Windows installer.

## Build configuration

Pass one or both endpoints at build time:

```bash
--dart-define=ANDROID_UPDATE_URL="https://example.com/client/android/update.json"
--dart-define=WINDOWS_UPDATE_URL="https://example.com/client/windows/update.json"
```

If an endpoint is empty, update checks are disabled for that platform.

## Manifest schema

```json
{
  "version": "1.0.1",
  "releaseNotes": "Bug fixes and experience improvements.",
  "packageUrl": "https://example.com/download/yourapp-1.0.1.apk",
  "packageUrlFallback": "https://mirror.example.com/yourapp-1.0.1.apk",
  "sha256": "",
  "size": 52428800,
  "setupUrl": "https://example.com/download/yourapp-1.0.1-setup.exe",
  "setupUrlFallback": "https://mirror.example.com/yourapp-1.0.1-setup.exe",
  "setupSha256": "",
  "setupSize": 73400320
}
```

Fields:

- `version`: Required. Compared with the app version in `pubspec.yaml`.
- `releaseNotes`: Optional text shown in the update dialog.
- `packageUrl`: Required for Android. Also used as the generic package URL.
- `packageUrlFallback`: Optional backup download URL.
- `sha256`: Optional SHA-256 for `packageUrl`. Leave empty to skip checking.
- `size`: Optional file size in bytes.
- `setupUrl`: Recommended for Windows. If present, Windows prefers it over
  `packageUrl`.
- `setupUrlFallback`: Optional backup Windows installer URL.
- `setupSha256`: Optional SHA-256 for `setupUrl`.
- `setupSize`: Optional Windows installer size in bytes.

Relative URLs are resolved against the manifest URL, so this is valid:

```json
{
  "version": "1.0.1",
  "releaseNotes": "Maintenance release.",
  "packageUrl": "./yourapp-1.0.1.apk"
}
```

## Hosting checklist

- Serve the manifest as JSON over HTTPS.
- Keep Android and Windows manifests separate when their versions or files
  differ.
- Use stable, cache-friendly download URLs.
- Update the manifest only after the package is fully uploaded.
- Add SHA-256 hashes for production releases when possible.
- Keep pre-release manifests separate from stable manifests.

## Client behavior

- The app checks at startup when auto-check is enabled.
- Manual check is available from the About page.
- Android downloads the APK and opens the installer.
- Windows downloads the installer and starts it.
- If the downloaded file hash does not match the manifest hash, the file is
  deleted and the update is rejected.

## Examples

Provider-neutral examples are available at:

- `examples/white-label/update.android.example.json`
- `examples/white-label/update.windows.example.json`
