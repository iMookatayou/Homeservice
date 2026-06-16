import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/auth_state.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/contractors_screen.dart';
import 'screens/purchase_screen.dart';
import 'screens/purchase_detail_screen.dart';
import 'screens/purchase_form_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/bill_form_screen.dart';
import 'screens/bills_summary_screen.dart';
import 'screens/bill_detail_screen.dart';
import 'models/bill.dart';
import 'screens/medicine_screen.dart';
import 'screens/medicine_form_screen.dart';
import 'screens/medicine_detail_screen.dart';
import 'screens/stocks_watchlist_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/stock_media_screen.dart';

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
      // Public
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),

      // Private
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/notes', builder: (_, __) => const NotesScreen()),
      GoRoute(path: '/contractors', builder: (_, __) => const ContractorsScreen()),

      // Purchases
      GoRoute(
        path: '/purchases',
        builder: (_, __) => const PurchaseScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const PurchaseFormScreen(mode: PurchaseFormMode.create),
          ),
          GoRoute(
            path: ':id',
            builder: (_, st) => PurchaseDetailScreen(id: st.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, st) => PurchaseFormScreen(
                  mode: PurchaseFormMode.edit,
                  id: st.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),

      // Bills
      GoRoute(
        path: '/bills',
        builder: (_, __) => const BillsScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const BillFormScreen()),
          GoRoute(path: 'summary', builder: (_, __) => const BillsSummaryScreen()),
          GoRoute(
            path: ':id',
            builder: (_, st) => BillDetailScreen(bill: st.extra as Bill),
          ),
        ],
      ),

      // Medicine
      GoRoute(
        path: '/medicine',
        builder: (_, __) => const MedicineScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const MedicineFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, st) => MedicineDetailScreen(id: st.pathParameters['id']!),
          ),
        ],
      ),

      // Stocks
      GoRoute(
        path: '/stocks',
        builder: (_, __) => const StocksWatchlistScreen(),
        routes: [
          GoRoute(
            path: ':watchId',
            builder: (_, st) =>
                StockDetailScreen(watchId: st.pathParameters['watchId']!),
            routes: [
              GoRoute(
                path: 'media',
                builder: (_, st) =>
                    StockMediaScreen(watchId: st.pathParameters['watchId']!),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (ctx, s) =>
        Scaffold(body: Center(child: Text('Route error: ${s.error}'))),

    redirect: (ctx, s) {
      final path = s.uri.path;
      final auth = ref.read(authProvider);

      if (auth.loading) return null;

      const public = {'/login', '/register', '/forgot'};
      final onSplash = path == '/splash';

      if (!auth.isAuthenticated) {
        if (onSplash) return '/login';
        if (!public.contains(path)) return '/login';
        return null;
      }

      if (auth.isAuthenticated && (onSplash || public.contains(path))) {
        return '/home';
      }
      return null;
    },
  );
});
