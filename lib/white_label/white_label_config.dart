import 'package:bett_box/common/merchant_config.dart';

const _whiteLabelDisplayName = String.fromEnvironment(
  'APP_DISPLAY_NAME',
  defaultValue: 'Cecil',
);
const whiteLabelLogoAsset = String.fromEnvironment(
  'APP_LOGO_ASSET',
  defaultValue: 'assets/images/cecil_logo_transparent.png',
);
const whiteLabelUriScheme = String.fromEnvironment(
  'APP_URI_SCHEME',
  defaultValue: 'cecil',
);
const _whiteLabelPanelBaseUrl = String.fromEnvironment('V2BOARD_PANEL_URL');
const _whiteLabelApiBaseUrl = String.fromEnvironment(
  'V2BOARD_API_BASE_URL',
  defaultValue: _whiteLabelPanelBaseUrl == ''
      ? ''
      : '$_whiteLabelPanelBaseUrl/api/v1',
);
const _whiteLabelHomeUrl = String.fromEnvironment('APP_HOME_URL');
const _whiteLabelWindowsUpdateUrl = String.fromEnvironment(
  'WINDOWS_UPDATE_URL',
);
const _whiteLabelAndroidUpdateUrl = String.fromEnvironment(
  'ANDROID_UPDATE_URL',
);
const _whiteLabelSupportUri = String.fromEnvironment('SUPPORT_URI');
const whiteLabelSupportUrl = String.fromEnvironment('SUPPORT_WEB_URL');
const _whiteLabelBootstrapProxy = String.fromEnvironment('BOOTSTRAP_PROXY_URI');
const whiteLabelBootstrapProxyName = String.fromEnvironment(
  'BOOTSTRAP_PROXY_NAME',
  defaultValue: 'bootstrap',
);
const whiteLabelBackendProxyPort = int.fromEnvironment(
  'BACKEND_PROXY_PORT',
  defaultValue: 7891,
);
final _whiteLabelDelayMultiplier =
    double.tryParse(
      const String.fromEnvironment('DELAY_MULTIPLIER', defaultValue: '1'),
    ) ??
    1;
const whiteLabelProfileId = String.fromEnvironment(
  'PROFILE_ID',
  defaultValue: 'cecil-provider-profile',
);
const _whiteLabelConfigTxtHost = String.fromEnvironment(
  'CONFIG_TXT_HOST',
  defaultValue: MerchantConfig.dnsHost,
);
const whiteLabelConfigCiphertext = String.fromEnvironment('CONFIG_CIPHERTEXT');
const whiteLabelDisclaimerText = String.fromEnvironment(
  'DISCLAIMER_TEXT',
  defaultValue:
      'Cecil 仅为本服务用户提供网络连接与订阅管理工具。请遵守所在地区法律法规及服务条款，不得用于违法违规用途。继续使用即表示你已阅读并同意本声明。',
);

const whiteLabelAuthTokenKey = 'white_label_auth_token';
const whiteLabelAuthDataKey = 'white_label_auth_data';
const whiteLabelAuthEmailKey = 'white_label_auth_email';

String get whiteLabelDisplayName {
  final value = MerchantConfig.displayName.trim();
  return value.isNotEmpty ? value : _whiteLabelDisplayName;
}

String get whiteLabelApiBaseUrl {
  final value = MerchantConfig.apiBaseUrl.trim();
  return value.isNotEmpty ? value : _whiteLabelApiBaseUrl;
}

String get whiteLabelPanelBaseUrl {
  final value = MerchantConfig.panelBaseUrl.trim();
  if (value.isNotEmpty) return value;
  return _derivePanelBaseUrl(_whiteLabelPanelBaseUrl, _whiteLabelApiBaseUrl);
}

String get whiteLabelHomeUrl {
  final value = MerchantConfig.homepageUrl.trim();
  return value.isNotEmpty ? value : _whiteLabelHomeUrl;
}

String get whiteLabelWindowsUpdateUrl {
  final value = MerchantConfig.windowsUpdateUrl.trim();
  return value.isNotEmpty ? value : _whiteLabelWindowsUpdateUrl;
}

String get whiteLabelAndroidUpdateUrl {
  final value = MerchantConfig.androidUpdateUrl.trim();
  return value.isNotEmpty ? value : _whiteLabelAndroidUpdateUrl;
}

String get whiteLabelSupportUri {
  final value = MerchantConfig.customerServiceUrl.trim();
  return value.isNotEmpty ? value : _whiteLabelSupportUri;
}

String get whiteLabelBootstrapProxy {
  final value = MerchantConfig.bootProxy.trim();
  return value.isNotEmpty ? value : _whiteLabelBootstrapProxy;
}

double get whiteLabelDelayMultiplier {
  final value = MerchantConfig.delayMultiplier;
  return value > 0 ? value : _whiteLabelDelayMultiplier;
}

String get whiteLabelConfigTxtHost {
  final value = MerchantConfig.dnsHost.trim();
  return value.isNotEmpty ? value : _whiteLabelConfigTxtHost;
}

String _derivePanelBaseUrl(String panelBaseUrl, String apiBaseUrl) {
  final panel = _withoutTrailingSlash(panelBaseUrl);
  if (panel.isNotEmpty) return panel;
  final api = _withoutTrailingSlash(apiBaseUrl);
  if (api.toLowerCase().endsWith('/api/v1')) {
    return api.substring(0, api.length - '/api/v1'.length);
  }
  return api;
}

String _withoutTrailingSlash(String value) {
  var next = value.trim();
  while (next.endsWith('/')) {
    next = next.substring(0, next.length - 1);
  }
  return next;
}
