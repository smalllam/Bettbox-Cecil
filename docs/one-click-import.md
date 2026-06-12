# One-click import

This document describes the provider-neutral one-click import flow used by the
white-label client.

## URL format

Use the same custom scheme on Android and Windows:

```text
yourapp://install-config?authData=<url-encoded-auth-data>
```

`authData` is the authenticated V2Board/xiaoV2b user credential returned by the
panel. The client stores it locally, fetches the user's subscription from the
configured panel API, downloads the subscription config, and hides the raw
subscription URL from the user.

Legacy profile import is still accepted with:

```text
yourapp://install-config?url=<url-encoded-subscription-url>
```

For white-label provider builds, prefer `authData` so the website does not
expose the real subscription URL.

## Client configuration

All three values must use the same scheme:

- Flutter build: `--dart-define=APP_URI_SCHEME=yourapp`
- Android build: `appScheme=yourapp` or `-PAPP_SCHEME=yourapp`
- Windows installer: `uri_scheme: yourapp` in
  `windows/packaging/exe/make_config.yaml`

Android also needs a unique package name:

```properties
appId=com.example.yourapp
appScheme=yourapp
```

Windows registers the scheme during installer setup.

## Website button

Use `encodeURIComponent` before appending `authData` to the URL.

```html
<button id="import-client">Import to client</button>

<script>
  const appScheme = 'yourapp';
  const authData = window.currentUserAuthData;
  const androidDownloadUrl = 'https://example.com/download/yourapp.apk';
  const windowsDownloadUrl = 'https://example.com/download/yourapp-setup.exe';

  function isWindows() {
    return /Windows/i.test(navigator.userAgent);
  }

  function fallbackUrl() {
    return isWindows() ? windowsDownloadUrl : androidDownloadUrl;
  }

  document.getElementById('import-client').addEventListener('click', () => {
    if (!authData) {
      alert('Please sign in first.');
      return;
    }

    const importUrl =
      `${appScheme}://install-config?authData=${encodeURIComponent(authData)}`;
    const openedAt = Date.now();
    window.location.href = importUrl;

    window.setTimeout(() => {
      if (Date.now() - openedAt < 1800) return;
      document.querySelector('#client-download')?.removeAttribute('hidden');
    }, 1500);
  });
</script>

<p id="client-download" hidden>
  Client not installed?
  <a href="https://example.com/download/yourapp.apk">Download Android</a>
  or
  <a href="https://example.com/download/yourapp-setup.exe">Download Windows</a>.
</p>
```

See `examples/white-label/one-click-login.html` for a complete standalone
example.

## Testing

Windows:

```powershell
Start-Process "yourapp://install-config?authData=TEST_AUTH_DATA"
```

Android:

```bash
adb shell am start \
  -a android.intent.action.VIEW \
  -d "yourapp://install-config?authData=TEST_AUTH_DATA"
```

Use a real `authData` from a test user when validating subscription sync.

## Security notes

- Generate `authData` only for the currently signed-in website user.
- Serve the website over HTTPS.
- Do not put the raw subscription URL in the page.
- Treat `authData` like a login credential. Avoid writing it to analytics,
  logs, screenshots, or public support tickets.
- If your panel can rotate auth data, rotate it when the user changes password
  or signs out of all devices.
