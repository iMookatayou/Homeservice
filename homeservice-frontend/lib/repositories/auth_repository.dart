import 'package:dio/dio.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';

class AuthRepository {
  final ApiClient _api;
  final TokenStorage _storage;

  AuthRepository({required TokenStorage storage})
      : _storage = storage,
        _api = ApiClient(tokenStorage: storage);

  Future<String?> currentToken() => _storage.getAccessToken();

  Future<User?> me() async {
    try {
      final res = await _api.get('/me');
      if (res.statusCode == 200 && res.data != null) {
        return User.fromJson((res.data as Map).cast<String, dynamic>());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<(String, User?)> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = (res.data as Map).cast<String, dynamic>();
    final token = _pickAccessToken(data);

    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'No token in response',
        type: DioExceptionType.badResponse,
      );
    }

    await _storage.saveTokens(token, null);

    final user = _parseUser(data);
    return (token, user);
  }

  Future<(String, User?)> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );

    final data = (res.data as Map).cast<String, dynamic>();
    final token = _pickAccessToken(data);

    if (token != null && token.isNotEmpty) {
      await _storage.saveTokens(token, null);
    }

    final user = _parseUser(data);
    return (token ?? '', user);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
    } finally {
      await _storage.clear();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    throw UnsupportedError('Password reset endpoint is not available yet');
  }

  User? _parseUser(Map<String, dynamic> data) {
    final userMap = data['user'];
    if (userMap is Map) {
      return User.fromJson(userMap.cast<String, dynamic>());
    }
    return null;
  }

  String? _pickAccessToken(Map<String, dynamic> data) {
    final root = data['access_token'] ?? data['token'];
    if (root is String && root.isNotEmpty) return root;

    final tokens = data['tokens'];
    if (tokens is Map) {
      final nested = tokens['access_token'] ?? tokens['token'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }
}
