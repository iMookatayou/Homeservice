import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod/riverpod.dart'
    show ProviderObserver, ProviderObserverContext;

import 'router.dart';
import 'state/auth_state.dart';

final class RiverpodLogger extends ProviderObserver {
  const RiverpodLogger();

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    debugPrint('[riverpod:add] ${context.provider} -> $value');
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    debugPrint(
      '[riverpod:update] ${context.provider} $previousValue -> $newValue',
    );
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    debugPrint('[riverpod:dispose] ${context.provider}');
  }

  @override
  void providerFailed(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '🛑 [riverpod:error] ${context.provider} -> $error\n$stackTrace',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(() {
    BindingBase.debugZoneErrorsAreFatal = true;
    return true;
  }());

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('🛑 [flutter] ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🛑 [platform] $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('🧱 [error-widget] ${details.exception}\n${details.stack}');
    return Material(
      color: Colors.white,
      child: Center(
        child: Text(
          'Widget Error:\n${details.exception}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 14),
        ),
      ),
    );
  };

  try {
    await dotenv.load(fileName: ".env.development");
    debugPrint('✅ dotenv loaded: .env.development');
  } catch (e1) {
    debugPrint("⚠️ dotenv load failed (.env.development): $e1");
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('✅ dotenv loaded: .env');
    } catch (e2) {
      debugPrint("⚠️ dotenv load failed (.env): $e2");
    }
  }

  runApp(
    const ProviderScope(observers: [RiverpodLogger()], child: HomeServiceApp()),
  );

  // ---- (หลัง runApp) probes ช่วยไล่จอดำ/เฟรมช้า ----
  // First-frame watchdog
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('[boot] first frame rendered');
  });
  Future.delayed(const Duration(seconds: 3), () {
    // ถ้าอยากเช็คเพิ่มว่ายังไม่มีเฟรม ให้ตั้ง flag เองได้
  });

  // Frame jank logger
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      final b = t.buildDuration.inMilliseconds;
      final r = t.rasterDuration.inMilliseconds;
      if (b > 32 || r > 32) {
        debugPrint('🐢 [frame] build=${b}ms raster=${r}ms');
      }
    }
  });

  // Isolate errors
  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) {
      final List<dynamic> errorAndStack = pair as List<dynamic>;
      debugPrint('🧨 [isolate] ${errorAndStack.first}\n${errorAndStack.last}');
    }).sendPort,
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
        final w = media.size.width;
        final h = media.size.height;
        if (w <= 0 || h <= 0) {
          debugPrint(
            '⚠️ [layout] invalid size: $w x $h, viewInsets=${media.viewInsets}',
          );
        }
        return MediaQuery(
          data: media.copyWith(textScaleFactor: clampedScale),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child:
                child ??
                const Scaffold(body: Center(child: Text('❌ Page not found'))),
          ),
        );
      },
    );
  }
}
