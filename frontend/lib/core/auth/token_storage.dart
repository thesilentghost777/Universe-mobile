import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

/// Sur le web, `flutter_secure_storage` chiffre les valeurs (AES-GCM via
/// WebCrypto) avant de les poser en `localStorage` — contrairement à
/// `SharedPreferences`, qui les y écrirait en clair (§11 : jamais de secret
/// en clair côté client). Web garde donc le même chemin que
/// mobile/desktop, pas de bascule spéciale.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'universe_access';
  static const _refreshKey = 'universe_refresh';

  Future<String?> readAccess() => _read(_accessKey);
  Future<String?> readRefresh() => _read(_refreshKey);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _write(_accessKey, access);
    await _write(_refreshKey, refresh);
  }

  Future<void> saveAccess(String access) => _write(_accessKey, access);

  Future<void> clear() async {
    await _delete(_accessKey);
    await _delete(_refreshKey);
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
