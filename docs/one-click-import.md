# One-click import

This document describes the provider-neutral one-click import flow used by the
white-label client.

## URL format

Use the same custom scheme on Android and Windows:

```text
yourapp://install-config?authData=<url-encoded-auth-data>
yourapp://install-config?token=<url-encoded-token>
yourapp://install-config?url=<url-encoded-subscription-url>
```

`authData` is the preferred authenticated V2Board/xiaoV2b user credential
returned by the panel. `token` is accepted for panels that only expose a user
token on the website. For both credential formats, the client stores the login
state locally, fetches the user's subscription from the configured panel API,
downloads the subscription config, and hides the raw subscription URL from the
user.

`url` is accepted as a compatibility fallback for older websites. Prefer
`authData` or `token` whenever possible because raw subscription URLs are
credentials and can be copied or leaked more easily.

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

Use `encodeURIComponent` before appending any credential or subscription URL.

```html
<button id="import-client">Import to client</button>

<script>
  const appScheme = 'yourapp';
  const authData = window.currentUserAuthData || '';
  const token = localStorage.getItem('token') || '';
  const subscribeUrl = localStorage.getItem('subscribe_url') || '';
  const androidDownloadUrl = 'https://example.com/download/yourapp.apk';
  const windowsDownloadUrl = 'https://example.com/download/yourapp-setup.exe';

  function isWindows() {
    return /Windows/i.test(navigator.userAgent);
  }

  function fallbackUrl() {
    return isWindows() ? windowsDownloadUrl : androidDownloadUrl;
  }

  function buildImportUrl() {
    if (authData) {
      return `${appScheme}://install-config?authData=${encodeURIComponent(authData)}`;
    }
    if (token) {
      return `${appScheme}://install-config?token=${encodeURIComponent(token)}`;
    }
    if (subscribeUrl) {
      return `${appScheme}://install-config?url=${encodeURIComponent(subscribeUrl)}`;
    }
    return '';
  }

  document.getElementById('import-client').addEventListener('click', () => {
    const importUrl = buildImportUrl();
    if (!importUrl) {
      alert('Please sign in first, then refresh this page.');
      return;
    }

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
Start-Process "yourapp://install-config?token=TEST_TOKEN"
```

Android:

```bash
adb shell am start \
  -a android.intent.action.VIEW \
  -d "yourapp://install-config?authData=TEST_AUTH_DATA"
```

Use a real `authData` or token from a test user when validating subscription
sync.

## Security notes

- Generate `authData` only for the currently signed-in website user.
- Serve the website over HTTPS.
- Avoid raw subscription URL import unless you need it for backward
  compatibility.
- Treat `authData`, `token`, and subscription URLs like login credentials. Avoid
  writing them to analytics, logs, screenshots, or public support tickets.
- If your panel can rotate auth data, rotate it when the user changes password
  or signs out of all devices.
