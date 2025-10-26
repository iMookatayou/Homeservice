// repositories/bill_repository.dart
import 'package:dio/dio.dart';
import '../models/bill.dart';
import '../models/bill_summary.dart';

class BillRepository {
  final Dio dio;
  BillRepository(this.dio);

  // ---- helpers ----
  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw const FormatException('Unexpected bills payload shape');
  }

  Map<String, dynamic> _extractObject(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map && data['data'] is Map) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    throw const FormatException('Unexpected bill payload shape');
  }

  Options get _okOnly => Options(
    // override validateStatus เฉพาะ call ของ Bills
    validateStatus: (c) => c != null && c >= 200 && c < 300,
  );

  Future<List<Bill>> list({String? query, String? status}) async {
    final res = await dio.get(
      '/bills',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      options: _okOnly,
    );
    final rows = _extractList(res.data);
    return rows.map(Bill.fromJson).toList();
  }

  Future<Bill> create({
    required String type,
    required String title,
    required double amount,
    required DateTime dueDate,
    required String status,
    String? note,
  }) async {
    final body = {
      'type': type,
      'title': title,
      'amount': amount,
      'due_date': dueDate.toUtc().toIso8601String(),
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await dio.post('/bills', data: body, options: _okOnly);
    return Bill.fromJson(_extractObject(res.data));
  }

  Future<List<BillSummary>> summary() async {
    final res = await dio.get('/bills/summary', options: _okOnly);
    final rows = _extractList(res.data);
    return rows.map(BillSummary.fromJson).toList();
  }

  Future<void> markPaid(String id) async {
    await dio.put('/bills/$id', data: {'status': 'paid'}, options: _okOnly);
  }
}
