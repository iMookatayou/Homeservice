import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/auth_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: HomeServiceApp()));
}

class HomeServiceApp extends ConsumerStatefulWidget {
  const HomeServiceApp({super.key});

  @override
  ConsumerState<HomeServiceApp> createState() => _HomeServiceAppState();
}

class _HomeServiceAppState extends ConsumerState<HomeServiceApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(
          path: '/forgot',
          builder: (_, __) => const ForgotPasswordScreen(),
        ),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      ],
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final loading = auth.loading;
        final authed = auth.isAuthenticated;
        final loc = state.uri.path;

        // หน้า public ที่เข้าถึงได้แม้ยังไม่ล็อกอิน
        const public = {'/splash', '/login', '/register', '/forgot'};

        if (loading) return null;

        // กัน redirect วนไป path เดิม
        String? go(String target) => (target == loc) ? null : target;

        if (!authed && !public.contains(loc)) return go('/login');
        if (authed && public.contains(loc)) return go('/home');
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ดู state ได้เพื่อ theme/อื่น ๆ แต่ไม่สร้าง router ซ้ำอีก
    ref.watch(authProvider);

    return MaterialApp.router(
      title: 'Home Service',
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5ED7),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
      ),
    );
  }
}
