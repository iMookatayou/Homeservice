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
  static bool _bootCalled = false;
  ProviderSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();

    _sub = ref.listenManual<AuthState>(authProvider, (prev, next) {
      if (!next.loading && mounted) {
        final dest = next.isAuthenticated ? '/home' : '/login';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          final current = GoRouter.of(
            context,
          ).routerDelegate.currentConfiguration.last.matchedLocation;

          if (current != dest) {
            context.go(dest);
          }
        });
      }
    });

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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
