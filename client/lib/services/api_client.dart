import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_storage.dart';
import 'auth_interceptor.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({Dio? dio, required this.tokenStorage, required Ref ref})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _baseUrl(),
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                responseType: ResponseType.json,
                validateStatus: (c) => c != null && c >= 200 && c < 400,
              ),
            ) {
    this.dio.interceptors.add(
      AuthInterceptor(storage: tokenStorage, ref: ref),
    );

    if (kDebugMode) {
      this.dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  static String _baseUrl() {
    final env = dotenv.env;
    final configured = env['API_BASE_URL'] ?? env['API_BASE'];
    if (configured != null && configured.isNotEmpty) {
      return _normalizeBaseUrl(configured);
    }

    final backend = env['BACKEND_BASE_URL'];
    if (backend != null && backend.isNotEmpty) {
      return _normalizeBaseUrl(
        backend.endsWith('/') ? '${backend}api/v1' : '$backend/api/v1',
      );
    }

    return _normalizeBaseUrl('http://127.0.0.1:8080/api/v1');
  }

  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return dio.get<T>(path, queryParameters: query, cancelToken: cancelToken);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return dio.post<T>(path, data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return dio.put<T>(path, data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return dio.patch<T>(path, data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(path, data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> getV1<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return get<T>(_v1Path(path), query: query, cancelToken: cancelToken);
  }

  Future<Response<T>> postV1<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return post<T>(_v1Path(path), data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> putV1<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return put<T>(_v1Path(path), data: data, cancelToken: cancelToken);
  }

  Future<Response<T>> deleteV1<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) {
    return delete<T>(_v1Path(path), data: data, cancelToken: cancelToken);
  }

  String _v1Path(String path) {
    var p = path.startsWith('/') ? path : '/$path';
    if (p.startsWith('/api/v1/')) {
      p = p.substring('/api/v1'.length);
    }
    return p;
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final ts = ref.read(tokenStorageProvider);
  return ApiClient(tokenStorage: ts, ref: ref);
});
