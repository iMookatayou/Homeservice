import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../providers.dart';

class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool loading;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.loading = true, // เริ่มต้นให้ Splash ไปสั่งโหลด
    this.error,
  });

  factory AuthState.unauthenticated() => const AuthState();

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
    _repo = ref.read(authRepositoryProvider); // อ่านทางเดียว
    return const AuthState(loading: true);
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final (token, user) = await _repo.register(
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
      return true;
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
      await _repo.login(email: email, password: password);
      final me = await _repo.me();
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
      // ignore
    } finally {
      state = const AuthState(loading: false);
    }
  }

  Future<void> tryLoadSession() async {
    if (_booting) return;
    _booting = true;
    try {
      debugPrint('[auth] tryLoadSession start');
      state = state.copyWith(loading: true, error: null);

      final token = await _repo.currentToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[auth] currentToken timeout');
          return null;
        },
      );

      if (token == null || token.isEmpty) {
        debugPrint('[auth] no token');
        state = const AuthState(loading: false);
        return;
      }

      final me = await _repo.me().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[auth] me() timeout');
          return null;
        },
      );

      if (me != null) {
        debugPrint('[auth] authed');
        state = state.copyWith(user: me, isAuthenticated: true, loading: false);
      } else {
        debugPrint('[auth] me null');
        state = const AuthState(loading: false);
      }
    } on DioException catch (e) {
      final msg = _extractError(e);
      debugPrint('[auth] DioException: $msg');
      state = AuthState(loading: false, error: msg);
    } catch (e) {
      debugPrint('[auth] unknown: $e');
      state = const AuthState(loading: false);
    } finally {
      _booting = false; // 👈 ปลดล็อค
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
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Network error (${e.response?.statusCode ?? '-'})';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
