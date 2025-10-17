import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../models/weather.dart';
import 'dart:async';

class LocationDeniedForever implements Exception {}

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(),
);

final locationProvider = FutureProvider<Position>((ref) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services are disabled.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw LocationDeniedForever();
  }
  if (permission == LocationPermission.denied) {
    throw Exception('Location permission denied.');
  }

  // 1) ลอง last known ก่อน — เร็ว
  final last = await Geolocator.getLastKnownPosition();
  if (last != null) return last;

  // 2) เอา current พร้อม timeout + accuracy กลาง ๆ
  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 5),
    );
  } on TimeoutException {
    // Fallback ถ้ารอ GPS นานเกินไป
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }
});

final currentWeatherProvider = FutureProvider<WeatherNow>((ref) async {
  final pos = await ref.watch(locationProvider.future);
  final ws = ref.read(weatherServiceProvider);
  return ws.getCurrent(pos.latitude, pos.longitude);
});
