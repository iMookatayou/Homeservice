// lib/services/medicine_api.dart
import 'package:dio/dio.dart';

import '../models/medicine_item.dart';
import '../models/medicine_detail.dart';
import '../models/medicine_location.dart';
import '../models/medicine_alert.dart';

// --- payloads เหมือนเดิม ---
class TxnOutPayload {
  final int qty;
  final String? note;
  TxnOutPayload({required this.qty, this.note});
  Map<String, dynamic> toJson() => {'qty': qty, 'note': note};
}

class TxnInPayload {
  final String? lotNo;
  final String? expiryDate; // YYYY-MM-DD
  final int qty;
  final String? note;
  TxnInPayload({this.lotNo, this.expiryDate, required this.qty, this.note});
  Map<String, dynamic> toJson() => {
    'lot_no': lotNo,
    'expiry_date': expiryDate,
    'qty': qty,
    'note': note,
  };
}

class CreateMedicinePayload {
  final String name;
  final String? form, unit, category, locationId;
  CreateMedicinePayload({
    required this.name,
    this.form,
    this.unit,
    this.category,
    this.locationId,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    if (form != null) 'form': form,
    if (unit != null) 'unit': unit,
    if (category != null) 'category': category,
    if (locationId != null) 'location_id': locationId,
  };
}

abstract class MedicineApi {
  Future<List<MedicineItem>> list({String? q});
  Future<MedicineDetail> detail(String id);
  Future<void> create(CreateMedicinePayload p);
  Future<void> txnOut(String id, TxnOutPayload p);
  Future<void> txnIn(String id, TxnInPayload p);
  Future<void> putAlert(String id, MedicineAlert a);
  Future<List<MedicineLocation>> locations();
}

class MedicineApiHttp implements MedicineApi {
  MedicineApiHttp(this._client);
  final Dio _client;

  static const _root = '/api/v1/medicine';
  static const _items = '$_root/items';

  // ===== 404-fallback helpers (คงเดิม) =====
  Future<Response<T>> _getWithFallback<T>(
    String primary, {
    String? fallback,
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _client.get<T>(primary, queryParameters: query);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && fallback != null) {
        return await _client.get<T>(fallback, queryParameters: query);
      }
      rethrow;
    }
  }

  Future<Response<T>> _postWithFallback<T>(
    String primary, {
    String? fallback,
    dynamic data,
  }) async {
    try {
      return await _client.post<T>(primary, data: data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && fallback != null) {
        return await _client.post<T>(fallback, data: data);
      }
      rethrow;
    }
  }

  Future<Response<T>> _putWithFallback<T>(
    String primary, {
    String? fallback,
    dynamic data,
  }) async {
    try {
      return await _client.put<T>(primary, data: data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && fallback != null) {
        return await _client.put<T>(fallback, data: data);
      }
      rethrow;
    }
  }

  // ===== APIs =====
  @override
  Future<List<MedicineItem>> list({String? q}) async {
    final query = (q == null || q.isEmpty) ? null : {'q': q};

    final res = await _getWithFallback<List<dynamic>>(
      _items, // 1) ลอง /medicine/items ก่อน
      fallback: _root, // 2) ถ้า 404 ค่อย /medicine
      query: query,
    );

    final list = (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();

    return list.map(MedicineItem.fromItemSummaryJson).toList();
  }

  @override
  Future<MedicineDetail> detail(String id) async {
    final res = await _getWithFallback<Map<String, dynamic>>(
      '$_items/$id',
      fallback: '$_root/$id',
    );

    // res.data เป็น Map<String, dynamic>? -> ใส่ ! หรือทำ default
    return MedicineDetail.fromJson(res.data!);
    // หรือใช้ default:
    // return MedicineDetail.fromJson((res.data ?? const <String, dynamic>{}));
  }

  @override
  Future<void> create(CreateMedicinePayload p) async {
    await _postWithFallback<void>(_items, fallback: _root, data: p.toJson());
  }

  @override
  Future<void> txnOut(String id, TxnOutPayload p) async {
    await _postWithFallback<void>(
      '$_items/$id/txns/out',
      fallback: '$_root/$id/txns/out',
      data: p.toJson(),
    );
  }

  @override
  Future<void> txnIn(String id, TxnInPayload p) async {
    await _postWithFallback<void>(
      '$_items/$id/txns/in',
      fallback: '$_root/$id/txns/in',
      data: p.toJson(),
    );
  }

  @override
  Future<void> putAlert(String id, MedicineAlert a) async {
    await _putWithFallback<void>(
      '$_items/$id/alert',
      fallback: '$_root/$id/alert',
      data: a.toJson(),
    );
  }

  @override
  Future<List<MedicineLocation>> locations() async {
    final res = await _getWithFallback<List<dynamic>>('$_root/locations');
    final data = (res.data ?? const <dynamic>[]).cast<Map<String, dynamic>>();
    return data.map(MedicineLocation.fromJson).toList();
  }
}
