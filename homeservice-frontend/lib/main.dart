import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'router.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (kDebugMode) debugPrint('🛑 [flutter] ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('🛑 [platform] $error');
    return true;
  };

  try {
    await dotenv.load(fileName: '.env.development');
    if (kDebugMode) debugPrint('✅ dotenv loaded');
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ dotenv load failed: $e');
  }

  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) {
      final List<dynamic> errorAndStack = pair as List<dynamic>;
      if (kDebugMode) debugPrint('🧨 [isolate] ${errorAndStack.first}');
    }).sendPort,
  );

  runApp(
    const ProviderScope(child: HomeServiceApp()),
  );
}

class HomeServiceApp extends ConsumerWidget {
  const HomeServiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Home Service',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5ED7),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clampedScale = media.textScaleFactor.clamp(0.9, 1.2);
        return MediaQuery(
          data: media.copyWith(textScaleFactor: clampedScale),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child ??
                const Scaffold(
                  body: Center(child: Text('❌ Page not found')),
                ),
          ),
        );
      },
    );
  }
}
