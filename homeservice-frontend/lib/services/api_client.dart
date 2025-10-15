import 'package:dio/dio.dart';
import 'package:homeservice/config/env.dart';
import 'token_storage.dart';
import 'dart:async';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  // ---- refresh queue กันยิงซ้ำ ----
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
              // ให้ 4xx/5xx โยน error -> onError จะถูกเรียก (จำเป็นต่อ refresh)
              validateStatus: (code) =>
                  code != null && code >= 200 && code < 400,
            ),
          ) {
    // Attach interceptors
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          // ถ้า 401 และยังไม่เคยรีไทร + ไม่ใช่ refresh เอง → refresh แล้วรีไทร
          if (_shouldTryRefresh(err)) {
            try {
              final response = await _handleTokenRefresh(err);
              return handler.resolve(response);
            } catch (_) {
              // refresh fail -> เคลียร์ token แล้วปล่อย error เดิม
              await tokenStorage.clear();
            }
          }
          handler.next(err);
        },
      ),
    );

    // Debug log (เฉพาะ debug)
    assert(() {
      this.dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
      return true;
    }());
  }

  static String _normalizeBaseUrl(String input) {
    // กัน baseUrl มี // ตอนต่อ path
    if (input.endsWith('/')) return input.substring(0, input.length - 1);
    return input;
  }

  bool _alreadyRetried(RequestOptions ro) => ro.extra['retried'] == true;

  bool _shouldTryRefresh(DioException err) {
    final status = err.response?.statusCode ?? 0;
    final p = err.requestOptions.path;
    if (status != 401) return false;
    if (_alreadyRetried(err.requestOptions)) return false;
    // อย่า refresh ถ้า endpoint นี้คือ refresh เอง (กันลูป)
    if (p.contains('/auth/refresh') || p.contains('/api/auth/refresh')) {
      return false;
    }
    return true;
  }

  Future<Response<dynamic>> _handleTokenRefresh(DioException err) async {
    // ถ้าเคยมี refresh กำลังทำอยู่ รอให้จบก่อน
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
    } else {
      _refreshCompleter = Completer<void>();
      try {
        final refresh = await tokenStorage.getRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          throw StateError('No refresh token');
        }

        // เรียก refresh token
        final refreshResp = await dio.post(
          // ปรับ path ให้ตรง backend
          '/api/auth/refresh',
          data: {'refresh_token': refresh},
          // อย่าแนบ Bearer เก่า (บางระบบไม่ต้อง/ห้าม)
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

    // รีไทรรีเควสเดิมด้วย access token ใหม่ (mark retried กันลูป)
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
      extra: {...req.extra, 'retried': true}, // mark retried once
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
