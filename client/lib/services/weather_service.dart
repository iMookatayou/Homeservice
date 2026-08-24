import 'package:dio/dio.dart';
import '../models/weather.dart';

class WeatherService {
  final Dio _dio;
  WeatherService([Dio? dio]) : _dio = dio ?? Dio();

  Future<WeatherNow> getCurrent(double lat, double lon) async {
    final url =
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto';
    final res = await _dio.get(url);
    final data = res.data['current'];
    return WeatherNow(
      temperature: (data['temperature_2m'] as num).toDouble(),
      windSpeed: (data['wind_speed_10m'] as num).toDouble(),
      weatherCode: (data['weather_code'] as num).toInt(),
      time: DateTime.parse(data['time']),
    );
  }
}
