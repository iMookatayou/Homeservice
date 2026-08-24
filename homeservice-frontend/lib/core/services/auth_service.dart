// lib/core/services/auth_service.dart
import 'package:dio/dio.dart';
import 'token_storage.dart';
import '../../features/auth/domain/user.dart';

class AuthRequired implements Exception {
  @override
  String toString() => 'AuthRequired';
}

class AuthService {
  final Dio dio;
  final Dio refreshDio;
  final TokenStorage storage;

  AuthService(this.dio, this.refreshDio, this.storage);

  Future<User> login(String email, String password) async {
    final resp = await dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = resp.data as Map<String, dynamic>;
    final tokens = data['tokens'];
    final access =
        (data['access_token'] ??
                data['token'] ??
                (tokens is Map
                    ? tokens['access_token'] ?? tokens['token']
                    : null))
            as String;
    final refresh = data['refresh_token'] as String?;
    await storage.saveTokens(access, refresh);
    return User.fromMap(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async {
    final resp = await dio.get('/me');
    return User.fromMap(resp.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (_) {
      /* เงียบไว้ */
    }
    await storage.clear();
  }

  Future<String> refreshToken() async {
    final rt = await storage.getRefreshToken();
    if (rt == null || rt.isEmpty) throw AuthRequired();
    final resp = await refreshDio.post(
      '/auth/refresh',
      data: {'refresh_token': rt},
    );
    if (resp.statusCode != 200) throw AuthRequired();
    final data = resp.data as Map<String, dynamic>;
    final newAccess = data['access_token'] as String;
    final newRefresh = (data['refresh_token'] ?? rt) as String;
    await storage.saveTokens(newAccess, newRefresh);
    return newAccess;
  }
}
