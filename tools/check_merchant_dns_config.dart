// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/merchant_crypto.dart';
import 'package:bett_box/models/merchant_config_data.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

Future<void> main() async {
  const host = String.fromEnvironment(
    'MERCHANT_CONFIG_DNS_HOST',
    defaultValue: '',
  );
  const secret = String.fromEnvironment('MERCHANT_CONFIG_KEY');
  if (host.trim().isEmpty) {
    stderr.writeln('Missing MERCHANT_CONFIG_DNS_HOST.');
    exit(2);
  }
  if (secret.trim().isEmpty) {
    stderr.writeln('Missing MERCHANT_CONFIG_KEY.');
    exit(2);
  }

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
      queryParameters: {'name': host, 'type': 'TXT'},
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '{}';
    final json = jsonDecode(body) as Map<String, dynamic>;
    final answer = json['Answer'] as List<dynamic>? ?? const [];
    final parts = <String>[];
    for (final item in answer) {
      if (item is! Map || item['type'] != 16) continue;
      parts.add((item['data']?.toString() ?? '').replaceAll('"', '').trim());
    }
    final cipher = parts.join();
    final plain = MerchantCrypto.decryptFromBase64Url(cipher, secret);
    final data = MerchantConfigData.fromPlainJson(plain);
    final digest = sha256.convert(utf8.encode(cipher)).toString();
    print(
      jsonEncode({
        'host': host,
        'cipherChars': cipher.length,
        'cipherSha256Prefix': digest.substring(0, 16),
        'keys': data.toCompactJson().keys.toList(),
        'apiBaseEndsWithApiV1': data.normalizedApiBaseUrl
            .toLowerCase()
            .endsWith('/api/v1'),
        'panelBaseHasApiV1': data.normalizedPanelBaseUrl.toLowerCase().endsWith(
          '/api/v1',
        ),
        'displayName': data.displayName,
        'delayMultiplier': data.delayMultiplier,
        'hasBootProxy': data.bootProxy.isNotEmpty,
        'hasSupport': data.customerServiceUrl.isNotEmpty,
      }),
    );
  } finally {
    dio.close(force: true);
  }
}
