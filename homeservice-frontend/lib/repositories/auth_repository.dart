// lib/repositories/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart'; // <= FIX: lib/repositories -> ../models

class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // -------- Register --------
  Future<(String token, User user)> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );

    final (token, user) = _extractTokenAndUser(res.data);
    await _persistToken(token);
    return (token, user);
  }

  // -------- Login --------
  Future<(String token, User user)> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final (token, user) = _extractTokenAndUser(res.data);
    await _persistToken(token);
    return (token, user);
  }

  // -------- Logout --------
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // ignore network error on logout
    } finally {
      await _clearToken();
    }
  }

  // -------- Me (single source of truth) --------
  Future<User?> me() async {
    try {
      final res = await _dio.get('/auth/me'); // <= FIX: consistent endpoint
      // รองรับทั้งแบบ { user: {...} } หรือ return เป็น {...} ตรง ๆ
      final data = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};

      final userJson = (data['user'] is Map<String, dynamic>)
          ? data['user'] as Map<String, dynamic>
          : data;

      return User.fromJson(userJson);
    } catch (_) {
      return null;
    }
  }

  // -------- Password Reset --------
  Future<void> requestPasswordReset(String email) async {
    await _dio.post('/auth/password/forgot', data: {'email': email});
  }

  // -------- Token helpers --------
  Future<String?> currentToken() => _storage.read(key: 'access_token');

  Future<void> _persistToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> _clearToken() async {
    await _storage.delete(key: 'access_token');
  }

  (String, User) _extractTokenAndUser(dynamic raw) {
    Map<String, dynamic> root;
    if (raw is Map<String, dynamic>) {
      root = raw;
    } else {
      root = <String, dynamic>{};
    }

    final data = (root['data'] is Map<String, dynamic>)
        ? root['data'] as Map<String, dynamic>
        : root;

    final token = (data['token'] ?? '').toString();
    final userMap =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    final user = User.fromJson(userMap);
    return (token, user);
  }
}
