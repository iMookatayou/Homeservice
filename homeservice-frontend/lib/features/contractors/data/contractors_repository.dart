import 'package:dio/dio.dart';
import '../models/contractor.dart';

class ContractorsRepository {
  final Dio _dio;
  ContractorsRepository(this._dio);

  Future<List<Contractor>> search({
    required double lat,
    required double lng,
    int radius = 5000,
    String? type,
    String? q,
  }) async {
    final resp = await _dio.get(
      'contractors/search',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        if (type != null && type.isNotEmpty) 'type': type,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return (resp.data as List)
        .map((e) => Contractor.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
