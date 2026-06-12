import 'dart:convert';

class MerchantConfigData {
  final String apiBaseUrl;
  final String androidUpdateUrl;
  final String windowsUpdateUrl;
  final String bootProxy;
  final double delayMultiplier;
  final String customerServiceUrl;
  final String homepageUrl;
  final String displayName;

  const MerchantConfigData({
    required this.apiBaseUrl,
    required this.androidUpdateUrl,
    required this.windowsUpdateUrl,
    required this.bootProxy,
    required this.delayMultiplier,
    required this.customerServiceUrl,
    required this.homepageUrl,
    required this.displayName,
  });

  Map<String, dynamic> toCompactJson() => {
    'p': apiBaseUrl,
    'aw': androidUpdateUrl,
    'ww': windowsUpdateUrl,
    'bp': bootProxy,
    'dm': delayMultiplier,
    'cs': customerServiceUrl,
    'h': homepageUrl,
    'n': displayName,
  };

  factory MerchantConfigData.fromCompactJson(Map<String, dynamic> json) {
    return MerchantConfigData(
      apiBaseUrl: _normalizeApiBaseUrl(json['p'] as String? ?? ''),
      androidUpdateUrl: json['aw'] as String? ?? '',
      windowsUpdateUrl: json['ww'] as String? ?? '',
      bootProxy: json['bp'] as String? ?? '',
      delayMultiplier: (json['dm'] as num?)?.toDouble() ?? 1,
      customerServiceUrl: json['cs'] as String? ?? '',
      homepageUrl: _normalizeUrl(json['h'] as String? ?? ''),
      displayName: json['n'] as String? ?? 'Cecil',
    );
  }

  String toPlainJson() => jsonEncode(toCompactJson());

  factory MerchantConfigData.fromPlainJson(String source) {
    return MerchantConfigData.fromCompactJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  String get normalizedApiBaseUrl => _withoutTrailingSlash(apiBaseUrl);

  String get normalizedPanelBaseUrl {
    final api = normalizedApiBaseUrl;
    if (api.toLowerCase().endsWith('/api/v1')) {
      return api.substring(0, api.length - '/api/v1'.length);
    }
    return api;
  }

  static String _normalizeApiBaseUrl(String value) {
    final url = _normalizeUrl(value);
    return _withoutTrailingSlash(url);
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  static String _withoutTrailingSlash(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
