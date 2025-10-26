import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import 'location_controller.dart';
import '../models/contractor.dart';
import '../repositories/contractors_repository.dart';

/// -------- Base URL resolver (อย่าลืมลงท้ายด้วย /) --------
String _resolveBaseUrl() {
  if (kIsWeb) return 'http://localhost:8080/api/v1/';
  if (Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1/';
  // iOS Simulator / macOS
  return 'http://127.0.0.1:8080/api/v1/';
}

final dioProvider = Provider<Dio>((ref) {
  final d = Dio(BaseOptions(baseUrl: _resolveBaseUrl()));
  d.interceptors.add(
    InterceptorsWrapper(
      onRequest: (opt, handler) {
        debugPrint('[DIO] ${opt.method} ${opt.uri}');
        handler.next(opt);
      },
      onResponse: (res, handler) {
        debugPrint('[DIO]<${res.statusCode}> ${res.requestOptions.uri}');
        handler.next(res);
      },
      onError: (err, handler) {
        debugPrint(
          '[DIO][ERR] ${err.requestOptions.uri} -> '
          '${err.response?.statusCode} ${err.message}',
        );
        handler.next(err);
      },
    ),
  );
  return d;
});

final contractorsRepoProvider = Provider<ContractorsRepository>(
  (ref) => ContractorsRepository(ref.watch(dioProvider)),
);

/// ---- Filter model ----
class ContractorFilter {
  final String? type; // electrician|plumber|carpenter|hvac
  final String q;
  final int radius; // meters
  const ContractorFilter({this.type, this.q = '', this.radius = 5000});

  ContractorFilter copyWith({String? type, String? q, int? radius}) {
    return ContractorFilter(
      type: type ?? this.type,
      q: q ?? this.q,
      radius: radius ?? this.radius,
    );
  }
}

/// ---- Notifier API (Riverpod v3) ----
class ContractorFilterNotifier extends Notifier<ContractorFilter> {
  @override
  ContractorFilter build() => const ContractorFilter();

  void setQuery(String q) => state = state.copyWith(q: q);
  void setType(String? type) => state = state.copyWith(type: type);
  void setRadius(int radius) => state = state.copyWith(radius: radius);
}

final contractorFilterProvider =
    NotifierProvider<ContractorFilterNotifier, ContractorFilter>(
      ContractorFilterNotifier.new,
    );

/// -------- พิกัดล่าสุดจริง (lastKnown → current fix), ไม่มี fallback --------
/// ข้อผิดพลาดที่โยน:
/// - 'location_service_disabled'
/// - 'location_permission_denied'
/// - 'location_unavailable'
final currentLatLngProvider = FutureProvider<({double lat, double lng})>((
  ref,
) async {
  // 0) Service / Permission
  final svc = await Geolocator.isLocationServiceEnabled();
  if (!svc) throw 'location_service_disabled';

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw 'location_permission_denied';
  }

  // 1) last known (เร็ว)
  final last = await Geolocator.getLastKnownPosition();
  if (last != null) {
    return (lat: last.latitude, lng: last.longitude);
  }

  // 2) current fix (แม่น, timeLimit กันค้าง)
  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      timeLimit: const Duration(seconds: 5),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  } on TimeoutException {
    throw 'location_unavailable';
  } catch (_) {
    throw 'location_unavailable';
  }
});

final contractorsListProvider = FutureProvider<List<Contractor>>((ref) async {
  final repo = ref.watch(contractorsRepoProvider);
  final filter = ref.watch(contractorFilterProvider);
  final uloc = ref.watch(locationControllerProvider);

  // ยังไม่รู้ตำแหน่ง → ยังไม่ยิง (ให้ UI แสดง loading/แบนเนอร์)
  if (uloc == null) return const <Contractor>[];

  return repo.search(
    lat: uloc.lat,
    lng: uloc.lng,
    radius: filter.radius,
    type: filter.type,
    q: filter.q.trim().isEmpty ? null : filter.q.trim(),
  );
});
