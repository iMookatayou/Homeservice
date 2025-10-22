import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeservice/config/env.dart';
import 'token_storage.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  /// เก็บ baseUrl ตอนสร้างไว้ใช้ในตัวช่วย path
  final String _baseUrl;

  Completer<void>? _refreshCompleter;

  ApiClient({Dio? dio, required this.tokenStorage})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _normalizeBaseUrl(Env.apiBaseUrl),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              responseType: ResponseType.json,
              validateStatus: (c) => c != null && c >= 200 && c < 400,
            ),
          ),
      _baseUrl = _normalizeBaseUrl(Env.apiBaseUrl) {
    // ==== Interceptors ====
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // --- normalize path ให้เข้ากับ baseUrl ก่อนส่ง ---
          final originalPath = options.path;
          final fixed = _fixPathForBase(originalPath, _baseUrl);
          if (fixed != originalPath) {
            assert(() {
              debugPrint(
                '[api] ⚠️ auto-fix path: "$originalPath" -> "$fixed" (base=$_baseUrl)',
              );
              return true;
            }());
            options.path = fixed;
          }

          // แนบ access token ถ้ามี
          final token = await tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (err, handler) async {
          if (_shouldTryRefresh(err)) {
            try {
              final response = await _handleTokenRefresh(err);
              return handler.resolve(response);
            } catch (_) {
              await tokenStorage.clear();
            }
          }
          handler.next(err);
        },
      ),
    );

    // Debug log เฉพาะโหมด debug
    assert(() {
      this.dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
      debugPrint('[api] base=$_baseUrl');
      return true;
    }());
  }

  // ===== Public helpers (เรียก API v1 แบบ safe) =====
  Future<Response<T>> getV1<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    final p = _v1Path(path);
    return dio.get<T>(p, queryParameters: query, cancelToken: cancelToken);
  }

  Future<Response<T>> postV1<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    final p = _v1Path(path);
    return dio.post<T>(p, data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> putV1<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    final p = _v1Path(path);
    return dio.put<T>(p, data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> deleteV1<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    final p = _v1Path(path);
    return dio.delete<T>(p, data: data, cancelToken: cancelToken);
  }

  // ===== Internals =====

  static String _normalizeBaseUrl(String input) {
    return input.endsWith('/') ? input.substring(0, input.length - 1) : input;
  }

  /// ปรับ path ให้เข้ากับ base ปัจจุบัน กันเคส /api/api/v1/*
  static String _fixPathForBase(String path, String baseUrl) {
    final p = path.startsWith('/') ? path : '/$path';
    if (p.startsWith('/api/api/')) {
      return p.replaceFirst('/api/api/', '/api/');
    }

    Uri uri;
    try {
      uri = Uri.parse(baseUrl);
    } catch (_) {
      return p;
    }

    final segs = uri.pathSegments;
    final hasApi = segs.contains('api');
    final hasV1 = segs.contains('v1');

    if (hasApi && hasV1) {
      // base .../api/v1
      if (p.startsWith('/api/v1/')) {
        return p.replaceFirst('/api/v1', '');
      }
      return p;
    }

    if (hasApi && !hasV1) {
      // base .../api
      if (p.startsWith('/api/v1/')) {
        return p.replaceFirst('/api', '');
      }
      return p;
    }

    // base ไม่มี /api
    if (p.startsWith('/v1/')) {
      return '/api$p';
    }
    return p;
  }

  /// path v1 ที่ถูกต้อง โดยดูจาก _baseUrl
  String _v1Path(String path) {
    final norm = path.startsWith('/') ? path : '/$path';

    Uri uri;
    try {
      uri = Uri.parse(_baseUrl);
    } catch (_) {
      return '/api/v1$norm';
    }

    final segs = uri.pathSegments; // e.g. ['api', 'v1']
    final hasApi = segs.contains('api');
    final hasV1 = segs.contains('v1');

    if (hasApi && hasV1) {
      // base .../api/v1
      return norm;
    } else if (hasApi && !hasV1) {
      // base .../api
      return '/v1$norm';
    } else {
      // base ไม่มี /api
      return '/api/v1$norm';
    }
  }

  bool _alreadyRetried(RequestOptions ro) => ro.extra['retried'] == true;

  bool _shouldTryRefresh(DioException err) {
    final status = err.response?.statusCode ?? 0;
    if (status != 401) return false;
    if (_alreadyRetried(err.requestOptions)) return false;

    final p = err.requestOptions.path;
    if (p.contains('/auth/refresh')) return false;
    return true;
  }

  Future<Response<dynamic>> _handleTokenRefresh(DioException err) async {
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
    } else {
      _refreshCompleter = Completer<void>();
      try {
        final refresh = await tokenStorage.getRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          throw StateError('No refresh token');
        }

        final refreshResp = await dio.post(
          _v1Path('/auth/refresh'),
          data: {'refresh_token': refresh},
          options: Options(headers: {'Authorization': null}),
        );

        final data = (refreshResp.data as Map).cast<String, dynamic>();
        final newAccess = (data['access_token'] ?? data['token']) as String?;
        final newRefresh = data['refresh_token'] as String?;

        if (newAccess == null || newAccess.isEmpty) {
          throw StateError('Refresh response missing access token');
        }

        await tokenStorage.saveTokens(newAccess, newRefresh);
      } finally {
        _refreshCompleter?.complete();
        _refreshCompleter = null;
      }
    }

    // retry คำขอเดิม
    final req = err.requestOptions;
    final newToken = await tokenStorage.getAccessToken();
    return _retry(req, newToken: newToken);
  }

  Future<Response<dynamic>> _retry(RequestOptions req, {String? newToken}) {
    final opts = Options(
      method: req.method,
      headers: {
        ...req.headers,
        if (newToken != null) 'Authorization': 'Bearer $newToken',
      },
      responseType: req.responseType,
      contentType: req.contentType,
      sendTimeout: req.sendTimeout,
      receiveTimeout: req.receiveTimeout,
      extra: {...req.extra, 'retried': true},
    );

    return dio.request<dynamic>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: opts,
      cancelToken: req.cancelToken,
      onSendProgress: req.onSendProgress,
      onReceiveProgress: req.onReceiveProgress,
    );
  }
}

// ===== Providers =====
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(); // ใช้ implementation ของคุณได้เลย
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final ts = ref.read(tokenStorageProvider);
  return ApiClient(tokenStorage: ts);
});
