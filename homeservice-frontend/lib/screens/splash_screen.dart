import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashState();
}

class _SplashState extends ConsumerState<SplashScreen> {
  // 👇 กันซ้ำระดับ “คลาส” (ทุกอินสแตนซ์ร่วมกัน)
  static bool _bootCalled = false;
  ProviderSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();

    // ฟังผลโหลดเสร็จแล้วค่อยนำทาง
    _sub = ref.listenManual<AuthState>(authProvider, (prev, next) {
      if (!next.loading && mounted) {
        final dest = next.isAuthenticated ? '/home' : '/login';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(dest);
        });
      }
    });

    // เรียกบูต 1 ครั้งทั้งแอป
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bootCalled) return;
      _bootCalled = true;
      await ref.read(authProvider.notifier).tryLoadSession();
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authProvider);
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
