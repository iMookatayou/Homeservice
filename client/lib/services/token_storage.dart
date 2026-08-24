import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final String namespace; // e.g. 'dev' | 'stg' | 'prod'
  final _ss = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  TokenStorage({this.namespace = 'default'});

  // in-memory cache
  String? _access;
  String? _refresh;

  // broadcast changes (login/logout/refresh)
  final _changes = StreamController<void>.broadcast();
  Stream<void> get onChange => _changes.stream;

  String _k(String key) => '$namespace:$key';

  Future<void> saveTokens(String access, String? refresh) async {
    // เขียนแบบอะตอมมิก + อัปเดตแคช
    _access = access;
    await _ss.write(key: _k(_kAccess), value: access);

    _refresh = refresh;
    if (refresh == null) {
      await _ss.delete(key: _k(_kRefresh));
    } else {
      await _ss.write(key: _k(_kRefresh), value: refresh);
    }
    _changes.add(null);
  }

  Future<String?> getAccessToken() async {
    if (_access != null) return _access;
    _access = await _ss.read(key: _k(_kAccess));
    return _access;
  }

  Future<String?> getRefreshToken() async {
    if (_refresh != null) return _refresh;
    _refresh = await _ss.read(key: _k(_kRefresh));
    return _refresh;
  }

  Future<bool> hasTokens() async =>
      (await getAccessToken())?.isNotEmpty == true;

  Future<Map<String, String>?> getAuthHeader() async {
    final t = await getAccessToken();
    if (t == null || t.isEmpty) return null;
    return {'Authorization': 'Bearer $t'};
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _ss.delete(key: _k(_kAccess));
    await _ss.delete(key: _k(_kRefresh));
    _changes.add(null);
  }
}
