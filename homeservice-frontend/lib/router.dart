// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/auth_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
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
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshNotifier(ref),

    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
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
      final auth = ref.read(authProvider);

      debugPrint(
        '[router] redirect check path=$path loading=${auth.loading} authed=${auth.isAuthenticated}',
      );

      if (auth.loading) return null;

      // แยก splash ออก ไม่ให้ถือเป็น public ที่อนุญาตค้างได้
      final onSplash = path == '/splash';
      const public = {'/login', '/register', '/forgot', '/forgotpassword'};

      if (!auth.isAuthenticated) {
        // ถ้ายังไม่ล็อกอินและอยู่ splash → บังคับไป login
        if (onSplash) return '/login';
        // ถ้าไม่ใช่หน้า public → บังคับไป login
        if (!public.contains(path)) return '/login';
        return null; // อนุญาตอยู่ที่หน้า public อื่น ๆ
      }

      // ล็อกอินแล้ว → กันกลับไป splash/login
      if (auth.isAuthenticated && (onSplash || public.contains(path))) {
        return '/home';
      }

      return null;
    },
  );
});
