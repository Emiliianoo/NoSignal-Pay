import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the access token in the platform's encrypted storage (Keychain on
/// iOS, Keystore-backed storage on Android), so it survives app restarts.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'access_token';

  final FlutterSecureStorage _storage;

  /// The saved token, or null when nobody is signed in.
  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> delete() => _storage.delete(key: _key);
}
