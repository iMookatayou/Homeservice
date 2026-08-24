// lib/services/auth_interceptor.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'token_storage.dart';
import '../providers.dart' show authServiceProvider;

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.storage, required this.ref});

  final TokenStorage storage;
  final Ref ref;

  Future<String?> _getAccess() => storage.getAccessToken();

  // กัน refresh ซ้อน
  Completer<String?>? _refreshing;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _getAccess();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final res = err.response;
    // ไม่ใช่ 401 → ปล่อยไป
    if (res?.statusCode != 401) return handler.next(err);

    // ถ้าเป็นทางของ auth ไม่ควรพยายาม refresh เพื่อเลี่ยง loop
    final path = err.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/register')) {
      return handler.next(err);
    }

    // ถ้าเคย retry แล้วอย่าทำซ้ำ (กัน loop)
    final alreadyRetried = err.requestOptions.extra['__ret'] == true;
    if (alreadyRetried) return handler.next(err);

    try {
      if (_refreshing == null) {
        _refreshing = Completer<String?>();
        try {
          final auth = ref.read(authServiceProvider);
          final newAccess = await auth.refreshToken();
          _refreshing!.complete(newAccess);
        } catch (e) {
          _refreshing!.completeError(e);
        }
      }
      final newToken = await _refreshing!.future;
      _refreshing = null;

      // ใส่ token ใหม่แล้ว retry คำขอเดิม
      final req = err.requestOptions;
      req.headers['Authorization'] = 'Bearer $newToken';
      req.extra['__ret'] = true;
      
      final auth = ref.read(authServiceProvider);
      final cloned = await auth.dio.fetch(req);
      return handler.resolve(cloned);
    } catch (_) {
      // refresh fail → ลบ token แล้วให้ upstream จัดการ (เช่นเด้งไปหน้า Login)
      await storage.clear();
      return handler.next(err);
    }
  }
}
