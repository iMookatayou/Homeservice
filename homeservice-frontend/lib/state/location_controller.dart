import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationSource { lastKnown, currentFix, stream, manual }

class UserLocation {
  final double lat;
  final double lng;
  final double? accuracy; // เมตร
  final LocationSource source;
  const UserLocation({
    required this.lat,
    required this.lng,
    this.accuracy,
    required this.source,
  });
}

class LocationController extends Notifier<UserLocation?> {
  StreamSubscription<Position>? _sub;

  @override
  UserLocation? build() {
    // auto-start เมื่อมี consumer
    _init();
    ref.onDispose(() {
      _sub?.cancel();
    });
    return null; // ยังไม่รู้ตำแหน่ง → ให้ UI แสดง loading/แบนเนอร์
  }

  Future<void> _init() async {
    // 1) ตรวจ service + permission
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      // รอจนผู้ใช้เปิด service แล้วค่อยกด refreshNow() จาก UI
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      // ให้ UI พาไป settings แล้วกด refresh อีกครั้ง
      return;
    }

    // 2) last known → เร็วมาก
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      state = UserLocation(
        lat: last.latitude,
        lng: last.longitude,
        accuracy: last.accuracy,
        source: LocationSource.lastKnown,
      );
    }

    // 3) current fix เร็วๆ (timeLimit กันค้าง)
    await refreshNow();

    // 4) ติดตามต่อเนื่องด้วยสตรีม (ประหยัดแบตด้วย distanceFilter)
    _sub?.cancel();
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 120, // อัปเดตเมื่อขยับ ~120 เมตร (ปรับได้)
          ),
        ).listen(
          (pos) {
            state = UserLocation(
              lat: pos.latitude,
              lng: pos.longitude,
              accuracy: pos.accuracy,
              source: LocationSource.stream,
            );
          },
          onError: (err, st) {
            if (kDebugMode) print('[loc:stream][err] $err');
          },
        );
  }

  /// ขอ fix ตอนนี้แบบด่วน (ใช้กับปุ่ม refresh หรือหลังกลับจาก Settings)
  Future<void> refreshNow() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        timeLimit: const Duration(seconds: 5),
      );
      state = UserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        source: LocationSource.currentFix,
      );
    } catch (e) {
      if (kDebugMode) print('[loc:currentFix][err] $e');
      // ถ้า fail ก็ปล่อยให้ lastKnown/stream ทำงานต่อ
    }
  }

  /// เผื่อกรณีให้ผู้ใช้เลือกพิกัดเองจากแผนที่/ปักหมุด (ถ้าจะทำภายหลัง)
  void setManual(double lat, double lng) {
    state = UserLocation(lat: lat, lng: lng, source: LocationSource.manual);
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, UserLocation?>(LocationController.new);
