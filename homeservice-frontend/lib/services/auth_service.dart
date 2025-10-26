// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import 'token_storage.dart';
import '../models/user.dart';

class AuthRequired implements Exception {
  @override
  String toString() => 'AuthRequired';
}

class AuthService {
  final Dio dio; // dio หลัก (มี interceptor ติดอยู่)
  final Dio refreshDio; // dio แยกใช้ refresh (ไม่มี interceptor กัน loop)
  final TokenStorage storage;

  AuthService(this.dio, this.refreshDio, this.storage);

  Future<User> login(String email, String password) async {
    final resp = await dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = resp.data as Map<String, dynamic>;
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String?;
    await storage.saveTokens(access, refresh);
    return User.fromMap(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async {
    final resp = await dio.get('/auth/me');
    return User.fromMap(resp.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await dio.post('/auth/logout'); // ถ้า backend มี endpoint นี้
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
