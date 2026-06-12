// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/merchant_crypto.dart';
import 'package:bett_box/models/merchant_config_data.dart';

const _dnsHost = String.fromEnvironment(
  'MERCHANT_CONFIG_DNS_HOST',
  defaultValue: 'nt-2.sxr.pics',
);
const _maxCipherBytes = 512;

Future<void> main(List<String> args) async {
  final plainPath = args.isNotEmpty ? args[0] : 'config/merchant.plain.json';
  final secretPath = args.length > 1 ? args[1] : 'config/merchant.secret';

  if (!File(plainPath).existsSync()) {
    stderr.writeln('Missing merchant plain config: $plainPath');
    exit(1);
  }
  if (!File(secretPath).existsSync()) {
    stderr.writeln('Missing merchant secret file: $secretPath');
    exit(1);
  }

  final plainRaw = File(plainPath).readAsStringSync().trim();
  final secret = File(secretPath).readAsStringSync().trim();
  if (secret.isEmpty) {
    stderr.writeln('Merchant secret cannot be empty.');
    exit(1);
  }

  final config = MerchantConfigData.fromPlainJson(plainRaw);
  final cipher = MerchantCrypto.encryptToBase64Url(
    config.toPlainJson(),
    secret,
  );
  final cipherBytes = utf8.encode(cipher).length;

  print('=== Merchant config cipher ===');
  print('Fields: ${config.toCompactJson().keys.join(', ')}');
  print('Cipher bytes: $cipherBytes / $_maxCipherBytes');
  print('DNS host: $_dnsHost (TXT)');
  print('');
  print('Upload this value to DNS TXT:');
  print(cipher);

  if (cipherBytes > _maxCipherBytes) {
    stderr.writeln('');
    stderr.writeln('Error: cipher exceeds $_maxCipherBytes bytes.');
    exit(2);
  }

  final roundTrip = MerchantCrypto.decryptFromBase64Url(cipher, secret);
  final restored = MerchantConfigData.fromPlainJson(roundTrip);
  if (restored.toPlainJson() != config.toPlainJson()) {
    stderr.writeln('Error: encryption round-trip check failed.');
    exit(3);
  }

  final outFile = File('config/merchant.cipher.txt');
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(cipher);
  print('');
  print('Written: ${outFile.path}');
}
