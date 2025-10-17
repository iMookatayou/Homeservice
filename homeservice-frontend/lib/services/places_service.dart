// lib/services/places_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/place.dart'; // ใช้ Place จาก models เท่านั้น

class PlacesService {
  final Dio _dio;

  PlacesService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl:
                  '${dotenv.env['BACKEND_BASE_URL'] ?? 'http://127.0.0.1:8080'}/api',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  Future<List<Place>> search({
    required double lat,
    required double lon,
    String type = 'shop',
    int radius = 1500,
  }) async {
    final res = await _dio.get(
      '/places',
      queryParameters: {'lat': lat, 'lon': lon, 'type': type, 'radius': radius},
    );
    final data = (res.data as List).cast<Map<String, dynamic>>();
    return data.map(Place.fromJson).toList();
  }
}
