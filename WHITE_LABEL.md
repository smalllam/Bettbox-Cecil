# White-label configuration

This repository is a neutral white-label client template. It does not include
provider domains, DNS TXT hosts, bootstrap proxy credentials, update manifests,
support vendor IDs, signing keys, or private assets.

## Required runtime configuration

Pass these values with `--dart-define` when building Flutter:

```bash
--dart-define=APP_DISPLAY_NAME="Your App"
--dart-define=APP_URI_SCHEME="yourapp"
--dart-define=APP_HOME_URL="https://example.com"
--dart-define=V2BOARD_PANEL_URL="https://panel.example.com"
```

`V2BOARD_API_BASE_URL` is optional. When omitted, the app uses
`$V2BOARD_PANEL_URL/api/v1`.

## Optional provider features

```bash
--dart-define=WINDOWS_UPDATE_URL="https://example.com/client/win/update.json"
--dart-define=ANDROID_UPDATE_URL="https://example.com/client/android/update.json"
--dart-define=SUPPORT_WEB_URL="https://support.example.com"
--dart-define=BOOTSTRAP_PROXY_URI="protocol://user:password@host:port?option=value"
--dart-define=BOOTSTRAP_PROXY_NAME="bootstrap"
--dart-define=BACKEND_PROXY_PORT=7891
--dart-define=DELAY_MULTIPLIER=1.0
--dart-define=DISCLAIMER_TEXT="Your provider disclaimer"
--dart-define=APP_ENV=pre
--dart-define=CONFIG_TXT_HOST="config.example.com"
--dart-define=CONFIG_CIPHERTEXT="..."
```

`SUPPORT_WEB_URL` is intentionally generic. It can point to Crisp, Intercom,
LiveChat, a Telegram bot page, a custom ticket system, or any support H5 page.
The client only opens the URL in its in-app WebView and manages the floating
support entry.

If `BOOTSTRAP_PROXY_URI` is empty, the client uses direct API access. If it is
set, the client can start a temporary local proxy for panel and subscription
requests.

`DISCLAIMER_TEXT` is optional. When it is empty, the app uses the default
localized disclaimer text. When it is provided, that provider-specific text is
shown in the disclaimer dialog and the user's acceptance is stored locally.

`APP_ENV=pre` is optional and only enables the pre-release badge. If omitted,
the app behaves as a release build.

## Android configuration

Set Android package and scheme through Gradle properties or `local.properties`:

```properties
appId=com.example.yourapp
appScheme=yourapp
```

The default Android package is `com.example.airportclient`, and the default
scheme is `airportclient`.

Do not commit signing files. `android/app/keystore.jks` and common key formats
are ignored.

## Windows configuration

Edit `windows/packaging/exe/make_config.yaml` for installer metadata:

```yaml
app_name: Your App
publisher: Your Company
publisher_url: https://example.com
display_name: Your App
executable_name: YourApp.exe
output_base_file_name: YourApp-1.0.0-windows-setup
uri_scheme: yourapp
helper_service_name: YourAppHelperService
```

The installer registers `yourapp://install-config?...` for one-click import.

## One-click import

Both Android and Windows support:

```text
yourapp://install-config?authData=<v2board-auth-data>
```

The app stores the auth data locally, fetches the subscription from the
configured V2Board panel, and does not display the subscription URL to users.

## Build examples

Android:

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi \
  --dart-define=APP_DISPLAY_NAME="Your App" \
  --dart-define=APP_URI_SCHEME="yourapp" \
  --dart-define=V2BOARD_PANEL_URL="https://panel.example.com" \
  --dart-define=SUPPORT_WEB_URL="https://support.example.com"
```

Windows:

```bash
flutter build windows --release \
  --dart-define=APP_DISPLAY_NAME="Your App" \
  --dart-define=APP_URI_SCHEME="yourapp" \
  --dart-define=V2BOARD_PANEL_URL="https://panel.example.com"
```
