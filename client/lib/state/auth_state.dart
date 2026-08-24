import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart' show tokenStorageProvider;

class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool loading;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.loading = true,
    this.error,
  });

  factory AuthState.unauthenticated() => const AuthState(loading: false);

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? loading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;
  bool _booting = false;

  @override
  AuthState build() {
    final storage = ref.read(tokenStorageProvider);
    _repo = AuthRepository(storage: storage, ref: ref);
    return const AuthState(loading: true);
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final (_, user) = await _repo.register(
        name: name,
        email: email,
        password: password,
      );
      final me = await _repo.me() ?? user;
      state = state.copyWith(
        user: me,
        isAuthenticated: me != null,
        loading: false,
      );
      return me != null;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _extractError(e));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Unexpected error');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final (_, user) = await _repo.login(email: email, password: password);
      final me = user ?? await _repo.me();
      state = state.copyWith(
        user: me,
        isAuthenticated: me != null,
        loading: false,
      );
      return me != null;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _extractError(e));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Unexpected error');
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.logout();
    } catch (_) {
    } finally {
      state = const AuthState(loading: false);
    }
  }

  Future<void> tryLoadSession() async {
    if (_booting) return;
    _booting = true;
    try {
      state = state.copyWith(loading: true, error: null);

      final token = await _repo.currentToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      if (token == null || token.isEmpty) {
        state = const AuthState(loading: false);
        return;
      }

      final me = await _repo.me().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (me != null) {
        state = state.copyWith(user: me, isAuthenticated: true, loading: false);
      } else {
        state = const AuthState(loading: false);
      }
    } on DioException catch (e) {
      state = AuthState(loading: false, error: _extractError(e));
    } catch (_) {
      state = const AuthState(loading: false);
    } finally {
      _booting = false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    try {
      await _repo.requestPasswordReset(email);
      return true;
    } catch (_) {
      state = state.copyWith(error: 'reset_failed');
      return false;
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return (data['error'] ?? data['message'] ?? 'Unknown error').toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return 'Network error (${e.response?.statusCode ?? '-'})';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
