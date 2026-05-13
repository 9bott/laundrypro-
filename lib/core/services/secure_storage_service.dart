import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted key-value store for sensitive data (tokens, session, biometric pref).
/// Backed by Keychain (iOS) and EncryptedSharedPreferences (Android).
abstract final class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> read(String key) => _storage.read(key: key);

  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<void> delete(String key) => _storage.delete(key: key);

  static Future<void> deleteAll() => _storage.deleteAll();

  static Future<bool> containsKey(String key) =>
      _storage.containsKey(key: key);
}
