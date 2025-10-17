import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';

class AuthRepository {
  final ApiClient _api;
  final TokenStorage _storage;

  AuthRepository({required TokenStorage storage})
    : _storage = storage,
      _api = ApiClient(tokenStorage: storage);

  // === Session helpers ===
  Future<String?> currentToken() => _storage.getAccessToken();

  Future<bool> attachSavedToken() async {
    final t = await _storage.getAccessToken();
    if (kDebugMode) debugPrint('[auth] attachSavedToken -> ${t != null}');
    return t != null && t.isNotEmpty;
  }

  Future<void> logout() async {
    try {
      await _api.postV1('/auth/logout');
    } catch (_) {
      // ignore if backend ไม่มี route นี้
    } finally {
      await _storage.clear();
    }
  }

  Future<User?> me() async {
    final res = await _api.getV1('/me');
    return _toUser(res.data);
  }

  // === Auth flows ===
  Future<(String, User?)> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.postV1(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = (res.data as Map).cast<String, dynamic>();

    final (token, refresh) = _pickTokens(data);
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'No token in response',
        type: DioExceptionType.badResponse,
      );
    }

    await _storage.saveTokens(token, refresh);

    final user = _pickUser(data);
    return (token, user);
  }

  Future<(String, User?)> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _api.postV1(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );

    final data = (res.data as Map).cast<String, dynamic>();

    final (token, refresh) = _pickTokens(data);
    if (token != null && token.isNotEmpty) {
      await _storage.saveTokens(token, refresh);
    }

    final user = _pickUser(data);
    return (token ?? '', user);
  }

  Future<void> requestPasswordReset(String email) async {
    await _api.postV1('/auth/forgot', data: {'email': email});
  }

  // === mappers & helpers ===

  /// รองรับหลายรูปแบบ:
  /// - { token, refresh_token }
  /// - { access_token, refresh_token }
  /// - { tokens: { access_token, refresh_token, expires_in } }
  /// - { data: { access_token, refresh_token } }
  (String?, String?) _pickTokens(Map<String, dynamic> m) {
    String? access;
    String? refresh;

    // root
    access = (m['token'] ?? m['access_token']) as String?;
    refresh = m['refresh_token'] as String?;

    // tokens nested
    if (access == null || access.isEmpty) {
      final t = m['tokens'];
      if (t is Map) {
        final tm = t.cast<String, dynamic>();
        access = (tm['access_token'] ?? tm['token']) as String?;
        refresh ??= tm['refresh_token'] as String?;
      }
    }

    // data nested
    if (access == null || access.isEmpty) {
      final d = m['data'];
      if (d is Map) {
        final dm = d.cast<String, dynamic>();
        access = (dm['access_token'] ?? dm['token']) as String?;
        refresh ??= dm['refresh_token'] as String?;
      }
    }

    return (access, refresh);
  }

  User? _pickUser(Map<String, dynamic> m) {
    if (m['user'] is Map) {
      return _toUser(m['user']);
    }
    if (m['data'] is Map && (m['data']['user'] is Map)) {
      return _toUser(m['data']['user']);
    }
    return null;
  }

  User _toUser(dynamic raw) {
    final mm = (raw as Map).cast<String, dynamic>();
    return User.fromJson(mm);
  }
}
