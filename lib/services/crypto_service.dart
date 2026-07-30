import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  static const _iterationCount = 100000;
  static const _keyLength = 32;

  static Uint8List deriveKey(String password, String saltBase64) {
    final salt = base64Decode(saltBase64);
    var result = Uint8List.fromList(password.codeUnits + salt);
    for (var i = 0; i < _iterationCount; i++) {
      result = Uint8List.fromList(sha256.convert(result).bytes);
    }
    return result.sublist(0, _keyLength);
  }

  static String generateSalt() {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(salt);
  }

  static Uint8List encrypt(Uint8List plaintext, Uint8List keyBytes) {
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
    return Uint8List.fromList(iv.bytes + encrypted.bytes);
  }

  static Uint8List decrypt(Uint8List ciphertext, Uint8List keyBytes) {
    final key = enc.Key(keyBytes);
    final ivBytes = ciphertext.sublist(0, 16);
    final encryptedBytes = ciphertext.sublist(16);
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(Uint8List.fromList(encryptedBytes)), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  static Uint8List extractIv(Uint8List ciphertext) {
    return Uint8List.fromList(ciphertext.sublist(0, 16));
  }

  static String keyToHex(Uint8List key) {
    return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List hexToKey(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
