// lib/providers.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'repositories/auth_repository.dart';

/// ==========================
/// Secure Storage (token)
/// ==========================
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

/// ==========================
/// Base URL resolver
/// - --dart-define=API_BASE_URL=https://api.example.com
/// - Android emulator -> 10.0.2.2
/// - iOS/macOS/Windows/Linux -> 127.0.0.1
/// - Web -> /api (แนะนำทำ reverse proxy)
/// ==========================
String _resolveBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;

  if (kIsWeb) return '/api';
  if (Platform.isAndroid) return 'http://10.0.2.2:8080';
  return 'http://127.0.0.1:8080';
}

/// ==========================
/// Dio (no circular deps)
/// - ไม่อ่าน/ไม่แตะ authProvider
/// - ใส่ Authorization จาก SecureStorage โดยตรง
/// ==========================
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: _resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (opt, handler) async {
        try {
          final token = await storage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            opt.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {
          // swallow
        }
        handler.next(opt);
      },
      onError: (e, handler) async {
        // ตัวเลือก: ล้าง token เมื่อ 401 (อย่าจัดการ state ของ authProvider ตรงนี้)
        if (e.response?.statusCode == 401) {
          try {
            await storage.delete(key: 'access_token');
          } catch (_) {}
        }
        handler.next(e);
      },
    ),
  );

  // Debug logger (เฉพาะ debug mode)
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
      ),
    );
    return true;
  }());

  return dio;
});

/// ==========================
/// Repositories
/// ==========================
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthRepository(dio, storage);
});

/// ==========================
/// (ทิป) วิธีรันด้วย baseUrl กำหนดเอง
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080
/// ==========================
