import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'services/token_storage.dart';
import 'services/api_client.dart' show ApiClient;
import 'services/auth_service.dart';
import 'repositories/auth_repository.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final ts = ref.read(tokenStorageProvider);
  return ApiClient(tokenStorage: ts, ref: ref);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final client = ref.read(apiClientProvider);
  
  final refreshDio = Dio(BaseOptions(
    baseUrl: client.dio.options.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  return AuthService(client.dio, refreshDio, storage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  return AuthRepository(storage: storage);
});
