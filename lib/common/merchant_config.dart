import 'dart:convert';

import 'package:bett_box/common/merchant_crypto.dart';
import 'package:bett_box/common/system.dart';
import 'package:bett_box/models/merchant_config_data.dart';
import 'package:dio/dio.dart';

class MerchantConfig {
  static const dnsHost = String.fromEnvironment(
    'MERCHANT_CONFIG_DNS_HOST',
    defaultValue: '',
  );
  static const maxCipherBytes = 512;
  static const configKeyEnv = 'MERCHANT_CONFIG_KEY';

  static MerchantConfigData? _data;

  static MerchantConfigData? get data => _data;

  static bool get isReady => _data != null;

  static String get displayName {
    final value = _data?.displayName.trim() ?? '';
    return value.isNotEmpty ? value : 'Cecil';
  }

  static String get apiBaseUrl => _data?.normalizedApiBaseUrl ?? '';

  static String get panelBaseUrl => _data?.normalizedPanelBaseUrl ?? '';

  static double get delayMultiplier {
    final value = _data?.delayMultiplier ?? 1;
    return value > 0 ? value : 1;
  }

  static String get homepageUrl => _data?.homepageUrl ?? '';

  static String get customerServiceUrl => _data?.customerServiceUrl ?? '';

  static String get bootProxy => _data?.bootProxy ?? '';

  static String get androidUpdateUrl => _data?.androidUpdateUrl ?? '';

  static String get windowsUpdateUrl => _data?.windowsUpdateUrl ?? '';

  static String get updateUrl {
    if (_data == null) return '';
    return system.isAndroid ? androidUpdateUrl : windowsUpdateUrl;
  }

  static int? applyDelayMultiplier(int? delay) {
    if (delay == null || delay <= 0) return delay;
    final multiplier = delayMultiplier;
    if (multiplier <= 1) return delay;
    return (delay / multiplier).round().clamp(1, delay);
  }

  static Future<void> initialize() async {
    final secret = const String.fromEnvironment(configKeyEnv);
    if (secret.trim().isEmpty) {
      throw StateError('Missing build define: $configKeyEnv');
    }
    if (dnsHost.trim().isEmpty) {
      throw StateError('Missing build define: MERCHANT_CONFIG_DNS_HOST');
    }
    final cipher = await _fetchDnsTxt();
    final plain = MerchantCrypto.decryptFromBase64Url(cipher, secret);
    _data = MerchantConfigData.fromPlainJson(plain);
    if (_data!.normalizedApiBaseUrl.isEmpty) {
      throw StateError('Merchant config is missing API base URL.');
    }
  }

  static Future<String> _fetchDnsTxt() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'accept': 'application/dns-json'},
      ),
    );
    try {
      final response = await dio.get<String>(
        'https://cloudflare-dns.com/dns-query',
        queryParameters: {'name': dnsHost, 'type': 'TXT'},
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data ?? '{}';
      final json = jsonDecode(body) as Map<String, dynamic>;
      final answer = json['Answer'] as List<dynamic>?;
      if (answer == null || answer.isEmpty) {
        throw StateError('DNS TXT record is empty: $dnsHost');
      }
      final parts = <String>[];
      for (final item in answer) {
        if (item is! Map) continue;
        if (item['type'] != 16) continue;
        final raw = item['data']?.toString() ?? '';
        parts.add(raw.replaceAll('"', '').trim());
      }
      final cipher = parts.join();
      if (cipher.isEmpty) {
        throw StateError('Unable to parse DNS TXT record: $dnsHost');
      }
      if (cipher.length > maxCipherBytes) {
        throw StateError('DNS TXT cipher exceeds $maxCipherBytes bytes.');
      }
      return cipher;
    } finally {
      dio.close(force: true);
    }
  }
}
