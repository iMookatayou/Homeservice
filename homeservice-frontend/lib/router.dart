import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeservice/screens/forgot_password_screen.dart';

import 'state/auth_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this.ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
  late final ProviderSubscription<AuthState> _sub;
  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshNotifier(ref),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgotpassword',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    ],
    errorBuilder: (ctx, s) =>
        Scaffold(body: Center(child: Text('Route error: ${s.error}'))),
    redirect: (ctx, s) {
      final path = s.uri.path;
      // print('[router] check $path loading=${auth.loading} authed=${auth.isAuthenticated}');
      if (auth.loading) return null;
      final isAuthPage = path == '/login' || path == '/register';
      if (!auth.isAuthenticated && path == '/splash') return '/login';
      if (!auth.isAuthenticated && !isAuthPage) return '/login';
      if (auth.isAuthenticated && (isAuthPage || path == '/splash')) {
        return '/home';
      }
      return null;
    },
  );
});
