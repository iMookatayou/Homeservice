// lib/state/notes_provider.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';

/// พารามิเตอร์ query สำหรับ list (immutable)
class NotesQuery {
  final int limit;
  final int offset;
  const NotesQuery({this.limit = 50, this.offset = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesQuery &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(limit, offset);
}

/// Provider หลัก: ดึงโน้ตจาก API จริง (เลิกใช้ mock)
final notesProvider = FutureProvider.autoDispose.family<List<Note>, NotesQuery>(
  (ref, query) async {
    final repo = ref.read(notesRepositoryProvider);

    // ให้ provider อยู่รอดชั่วคราวเวลาเปลี่ยนหน้า/เลื่อน tab
    final link = ref.keepAlive();
    Timer? _timer;
    ref.onCancel(() {
      // รอ 30s ก่อนปิดจริง ลดการรีเฟรชถี่ ๆ เวลา user สลับจอ
      _timer = Timer(const Duration(seconds: 30), () {
        link.close();
      });
    });
    ref.onResume(() {
      _timer?.cancel();
    });

    // ยกเลิก request เมื่อ provider ถูก dispose
    final cancel = CancelToken();
    ref.onDispose(() {
      if (!cancel.isCancelled) cancel.cancel('notesProvider disposed');
    });

    try {
      final items = await repo.list(
        limit: query.limit,
        offset: query.offset,
        cancelToken: cancel,
      );
      return items;
    } on DioException catch (e) {
      // แปลงเป็นข้อความสั้น ๆ อ่านง่าย (หลีกเลี่ยง error block ยาว)
      final sc = e.response?.statusCode;
      if (sc == 401) {
        throw Exception('ไม่ได้รับอนุญาต (401) — กรุณาเข้าสู่ระบบอีกครั้ง');
      }
      if (sc == 404) {
        throw Exception(
          'ไม่พบข้อมูลโน้ต (404) — อาจยังไม่มีโน้ตหรือ endpoint ผิด',
        );
      }
      throw Exception('โหลดโน้ตล้มเหลว: ${sc ?? ''} ${e.message}');
    }
  },
);
