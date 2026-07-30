import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final encryptionPasswordProvider = StateProvider<String>((ref) => '');
final encryptionKeyHexProvider = StateProvider<String>((ref) => '');

class EncryptionConfig {
  static const _pwdKey = 'enc_password';
  static const _saltKey = 'enc_salt';
  static const _keyHexKey = 'enc_key_hex';

  static Future<({String password, String salt, String keyHex})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      password: prefs.getString(_pwdKey) ?? '',
      salt: prefs.getString(_saltKey) ?? '',
      keyHex: prefs.getString(_keyHexKey) ?? '',
    );
  }

  static Future<void> save({
    required String password,
    required String salt,
    required String keyHex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pwdKey, password);
    await prefs.setString(_saltKey, salt);
    await prefs.setString(_keyHexKey, keyHex);
  }

  static Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pwdKey);
    await prefs.remove(_saltKey);
    await prefs.remove(_keyHexKey);
  }
}
