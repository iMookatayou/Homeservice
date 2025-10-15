import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final _ss = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveTokens(String access, String? refresh) async {
    await _ss.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _ss.write(key: _kRefresh, value: refresh);
    }
  }

  Future<String?> getAccessToken() => _ss.read(key: _kAccess);
  Future<String?> getRefreshToken() => _ss.read(key: _kRefresh);

  Future<void> clear() async {
    await _ss.delete(key: _kAccess);
    await _ss.delete(key: _kRefresh);
  }
}
