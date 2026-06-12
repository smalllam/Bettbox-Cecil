import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class MerchantCrypto {
  static Uint8List deriveKey(String secret) {
    final digest = sha256.convert(utf8.encode(secret.trim()));
    return Uint8List.fromList(digest.bytes);
  }

  static String encryptToBase64Url(String plainText, String secret) {
    final key = Key(deriveKey(secret));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final payload = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return base64Url.encode(payload).replaceAll('=', '');
  }

  static String decryptFromBase64Url(String cipherText, String secret) {
    final normalized = cipherText.replaceAll(RegExp(r'\s+'), '');
    final padded = normalized.padRight(
      normalized.length + ((4 - normalized.length % 4) % 4),
      '=',
    );
    final payload = base64Url.decode(padded);
    if (payload.length < 17) {
      throw const FormatException('Invalid merchant cipher length.');
    }
    final iv = IV(payload.sublist(0, 16));
    final data = Encrypted(payload.sublist(16));
    final key = Key(deriveKey(secret));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt(data, iv: iv);
  }
}
