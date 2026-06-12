const whiteLabelDisplayName = String.fromEnvironment(
  'APP_DISPLAY_NAME',
  defaultValue: 'Airport Client',
);
const whiteLabelLogoAsset = String.fromEnvironment(
  'APP_LOGO_ASSET',
  defaultValue: 'assets/images/icon.png',
);
const whiteLabelUriScheme = String.fromEnvironment(
  'APP_URI_SCHEME',
  defaultValue: 'airportclient',
);
const whiteLabelPanelBaseUrl = String.fromEnvironment('V2BOARD_PANEL_URL');
const whiteLabelApiBaseUrl = String.fromEnvironment(
  'V2BOARD_API_BASE_URL',
  defaultValue: whiteLabelPanelBaseUrl == ''
      ? ''
      : '$whiteLabelPanelBaseUrl/api/v1',
);
const whiteLabelHomeUrl = String.fromEnvironment('APP_HOME_URL');
const whiteLabelWindowsUpdateUrl = String.fromEnvironment('WINDOWS_UPDATE_URL');
const whiteLabelAndroidUpdateUrl = String.fromEnvironment('ANDROID_UPDATE_URL');
const whiteLabelSupportUri = String.fromEnvironment('SUPPORT_URI');
const whiteLabelSupportUrl = String.fromEnvironment('SUPPORT_WEB_URL');
const whiteLabelBootstrapProxy = String.fromEnvironment('BOOTSTRAP_PROXY_URI');
const whiteLabelBootstrapProxyName = String.fromEnvironment(
  'BOOTSTRAP_PROXY_NAME',
  defaultValue: 'bootstrap',
);
const whiteLabelBackendProxyPort = int.fromEnvironment(
  'BACKEND_PROXY_PORT',
  defaultValue: 7891,
);
final whiteLabelDelayMultiplier =
    double.tryParse(
      const String.fromEnvironment('DELAY_MULTIPLIER', defaultValue: '1'),
    ) ??
    1;
const whiteLabelProfileId = String.fromEnvironment(
  'PROFILE_ID',
  defaultValue: 'default-provider-profile',
);
const whiteLabelConfigTxtHost = String.fromEnvironment('CONFIG_TXT_HOST');
const whiteLabelConfigCiphertext = String.fromEnvironment('CONFIG_CIPHERTEXT');

const whiteLabelAuthTokenKey = 'white_label_auth_token';
const whiteLabelAuthDataKey = 'white_label_auth_data';
const whiteLabelAuthEmailKey = 'white_label_auth_email';
