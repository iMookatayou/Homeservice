import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/token_storage.dart';
import 'services/api_client.dart' show ApiClient;
import 'repositories/auth_repository.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final ts = ref.read(tokenStorageProvider);
  return ApiClient(tokenStorage: ts);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  return AuthRepository(storage: storage);
});
