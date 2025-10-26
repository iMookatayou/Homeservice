import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ต้องใช้ชื่อ package ตรงกับ pubspec.yaml: name: homeservice
import 'package:homeservice/services/purchase_api.dart';
import 'package:homeservice/repositories/purchase_repository.dart';
import 'package:homeservice/models/purchase_model.dart';

import 'package:homeservice/services/token_storage.dart';
import 'auth_state.dart'
    show authProvider; // เราจะทำ adapter ดึง token ด้านล่าง

/* ---------------- Base URL resolver ---------------- */

final purchasesBaseUrlProvider = Provider<String>((ref) {
  final env = dotenv.env;
  final apiBase = env['API_BASE'] ?? env['API_BASE_URL'];
  if (apiBase != null && apiBase.isNotEmpty) return apiBase;

  final backend = env['BACKEND_BASE_URL'];
  if (backend != null && backend.isNotEmpty) {
    return backend.endsWith('/') ? '${backend}api/v1' : '$backend/api/v1';
  }

  // iOS Simulator; Android Emulator ใช้ 10.0.2.2
  return 'http://127.0.0.1:8080/api/v1';
});

/* ---------------- Token sources ---------------- */

// 0) Adapter: ดึง token จาก authProvider ของโปรเจกต์คุณ โดยไม่พึ่ง maybeWhen
final authAccessTokenProvider = Provider<String?>((ref) {
  final s = ref.watch(authProvider);
  // ปรับ logic ให้ตรงกับโครงสร้างจริงของคุณ:
  // ตัวอย่างทั่วไป:
  // - ถ้า s เป็นคลาส AuthState มีฟิลด์ user/token:
  //   return s.user?.token;
  // - ถ้า s เป็น AsyncValue<User?>:
  //   return s.valueOrNull?.token;
  // - ถ้า s เป็น sealed class: Unauth / Auth(User)
  //   if (s is Auth) return s.user.token; else return null;

  // ใส่ fallback ให้ build ผ่านก่อน ถ้าคุณยังไม่ผูก auth จริง:
  try {
    // ignore: avoid_dynamic_calls
    final token = (s as dynamic)?.user?.token as String?;
    return token;
  } catch (_) {
    return null;
  }
});

// 1) Secure storage (ตอนแอปบูตใหม่ยังไม่ hydrate auth state)
final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());
final secureStorageTokenProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(tokenStorageProvider);
  return storage.getAccessToken();
});

// 2) .env (dev-only fallback)
final envTokenProvider = Provider<String?>((ref) {
  final t = dotenv.env['AUTH_TOKEN'];
  return (t != null && t.isNotEmpty) ? t : null;
});

/* ---------------- Dio with dynamic Bearer ---------------- */

final purchasesDioProvider = Provider<Dio>((ref) {
  final base = ref.watch(purchasesBaseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      validateStatus: (code) => true, // ให้ PurchaseApi map เอง
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (opt, handler) async {
        // เรียงลำดับ: auth state -> secure storage -> .env
        String? token = ref.read(authAccessTokenProvider);

        if (token == null || token.isEmpty) {
          token = await ref
              .read(secureStorageTokenProvider.future)
              .timeout(
                const Duration(milliseconds: 300),
                onTimeout: () => null,
              );
        }
        token ??= ref.read(envTokenProvider);

        if (kDebugMode) {
          debugPrint('[REQ] ${opt.method} ${opt.uri}');
          debugPrint('[AUTH] attach? ${token != null && token.isNotEmpty}');
        }
        if (token != null && token.isNotEmpty) {
          opt.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(opt);
      },
    ),
  );

  return dio;
});

/* ---------------- API / Repo ---------------- */

final purchaseApiProvider = Provider<PurchaseApi>((ref) {
  final dio = ref.watch(purchasesDioProvider);
  return PurchaseApi(dio);
});

final purchaseRepoProvider = Provider<PurchaseRepository>((ref) {
  final api = ref.watch(purchaseApiProvider);
  return PurchaseRepository(api);
});

/* ---------------- Queries ---------------- */

final purchasesListProvider = FutureProvider.autoDispose<List<Purchase>>((
  ref,
) async {
  return ref.watch(purchaseRepoProvider).list();
});

final purchaseDetailProvider = FutureProvider.autoDispose
    .family<Purchase, String>((ref, id) async {
      return ref.watch(purchaseRepoProvider).getById(id);
    });
