import 'package:dio/dio.dart';
import 'token_storage.dart';
import '../models/user.dart';

class AuthService {
  final Dio dio;
  final TokenStorage storage;
  AuthService(this.dio, this.storage);

  Future<User> login(String email, String password) async {
    final resp = await dio.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = resp.data as Map<String, dynamic>;
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String?;
    await storage.saveTokens(access, refresh);
    return User.fromMap(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async {
    final resp = await dio.get('/api/auth/me');
    return User.fromMap(resp.data as Map<String, dynamic>);
  }

  Future<void> logout() => storage.clear();
}
