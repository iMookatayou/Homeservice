import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider); // AuthState
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Service'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: auth.loading
            ? const CircularProgressIndicator()
            : Text(
                user != null ? 'ยินดีต้อนรับ, ${user.name}' : 'ยินดีต้อนรับ',
              ),
      ),
    );
  }
}
