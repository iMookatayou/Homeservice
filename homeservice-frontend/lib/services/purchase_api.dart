// lib/services/purchase_api.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:homeservice/models/purchase_model.dart';

/// ---------- Exceptions (ให้ UI/Providers จับง่าย) ----------
class AuthRequired implements Exception {
  final String? message;
  AuthRequired([this.message]);
  @override
  String toString() => 'AuthRequired: ${message ?? ''}';
}

class ConflictError implements Exception {
  final String? message;
  ConflictError([this.message]);
  @override
  String toString() => 'ConflictError: ${message ?? ''}';
}

class NotFoundError implements Exception {
  final String? message;
  NotFoundError([this.message]);
  @override
  String toString() => 'NotFoundError: ${message ?? ''}';
}

class ApiError implements Exception {
  final int? status;
  final String? message;
  ApiError({this.status, this.message});
  @override
  String toString() => 'ApiError($status): ${message ?? ''}';
}

/// Low-level API client สำหรับโมดูล Purchases
/// - ใช้ Dio ที่ถูกฉีดมาพร้อม baseUrl และ Authorization interceptor แล้ว
/// - JSON เป็น snake_case ตาม backend
class PurchaseApi {
  final Dio _dio;
  PurchaseApi(this._dio);

  // ------------ Helpers ------------
  T _ok<T>(Response resp, T Function(dynamic json) parse) {
    final s = resp.statusCode ?? 0;
    // จัดการ error code ที่พบบ่อยให้เป็น exception เฉพาะ
    if (s == 401) {
      throw AuthRequired(_extractMessage(resp.data));
    }
    if (s == 404) {
      throw NotFoundError(_extractMessage(resp.data));
    }
    if (s == 409) {
      throw ConflictError(_extractMessage(resp.data));
    }
    if (s < 200 || s >= 300) {
      throw ApiError(status: s, message: _extractMessage(resp.data));
    }
    return parse(resp.data);
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] is String)
      return data['message'] as String;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }

  List<Purchase> _parseList(dynamic data) {
    if (data is List) {
      return data
          .map<Purchase>(
            (e) => Purchase.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .map<Purchase>(
            (e) => Purchase.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }
    throw StateError('Unexpected list payload: $data');
  }

  Purchase _parseOne(dynamic data) {
    return Purchase.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ------------ Endpoints ------------

  /// GET /purchases
  Future<List<Purchase>> list({int? limit, int? offset}) async {
    final resp = await _dio.get(
      '/purchases',
      queryParameters: {
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );
    return _ok(resp, _parseList);
  }

  /// GET /purchases/{id}
  Future<Purchase> getById(String id) async {
    final resp = await _dio.get('/purchases/$id');
    return _ok(resp, _parseOne);
  }

  /// POST /purchases
  Future<Purchase> create(CreatePurchasePayload payload) async {
    final resp = await _dio.post('/purchases', data: payload.toJson());
    return _ok(resp, _parseOne);
  }

  /// PATCH /purchases/{id}
  Future<Purchase> update(String id, UpdatePurchasePayload payload) async {
    final resp = await _dio.patch('/purchases/$id', data: payload.toJson());
    return _ok(resp, _parseOne);
  }

  /// DELETE /purchases/{id}
  Future<void> delete(String id) async {
    final resp = await _dio.delete('/purchases/$id');
    _ok(resp, (_) => true); // 200/204 ok, อื่นๆ โยน error ตามสถานะ
  }

  /// POST /purchases/{id}/claim
  Future<Purchase> claim(String id) async {
    final resp = await _dio.post('/purchases/$id/claim');
    return _ok(resp, _parseOne);
  }

  /// POST /purchases/{id}/progress
  /// nextStatus: 'ordered' | 'bought' | 'delivered'
  /// amountPaid: ใช้ตอน 'bought' (optional)
  Future<Purchase> progress(String id, ProgressPayload payload) async {
    final resp = await _dio.post(
      '/purchases/$id/progress',
      data: payload.toJson(),
    );
    return _ok(resp, _parseOne);
  }

  /// POST /purchases/{id}/cancel
  Future<Purchase> cancel(String id) async {
    final resp = await _dio.post('/purchases/$id/cancel');
    return _ok(resp, _parseOne);
  }

  /// POST /purchases/{id}/attachments (multipart/form-data)
  Future<Purchase> uploadAttachment({
    required String id,
    required File file,
    String? filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: filename),
    });
    final resp = await _dio.post('/purchases/$id/attachments', data: form);
    return _ok(resp, _parseOne);
  }

  /// DELETE /purchases/{id}/attachments/{file_id}
  Future<Purchase> deleteAttachment({
    required String id,
    required String fileId,
  }) async {
    final resp = await _dio.delete('/purchases/$id/attachments/$fileId');
    return _ok(resp, _parseOne);
  }
}
